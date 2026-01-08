#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/InlineAsm.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Support/TargetSelect.h"

#include <format>

namespace nop::detail {
    // rand 
    int rand() {
        static int seed = 0;
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        return seed;
    }

    template<typename T, size_t N>
    T& pick(T(&arr)[N]) {
        return arr[rand() % N];
    }

    std::string reg[] = {
            "rax", "rbx", "rcx", "rdx",
            "rsi", "rdi", "rbp", "rsp",
            "r8", "r9", "r10", "r11",
            "r12", "r13", "r14", "r15"
    };

    std::string jmpc[] = {
        "a", "b", "c", "e", "g", "l", "o", "p", "s", "z"
    };
    std::string gen_push() {
        return std::format("pushq %{}\n", pick(reg));
    }

    std::string gen_lea() {
        return std::format("leaq -0x{}(%rip),%{}\n", rand() % 41 + 10, pick(reg));
    }

    std::string gen_mov() {
        return std::format("movq %{0}, %{1}\n", pick(reg), pick(reg));
    }

    std::string gen_cmp() {
        return std::format("cmpq %{0}, %{1}\n", pick(reg), pick(reg));
    }

    std::string gen_jcc() {
        return std::format(".byte 0x{:02x}, 0x{:02x}\n", rand() % 16 + 0x70, rand()%127 + 0x80);
    }

    std::string gen_call() {
        return std::format(".byte 0xe8, 0x{:02x}, 0x{:02x}, 0xff, 0xff\n", rand() % 256, rand() % 256);
    }

    std::string gen_pop() {
        return std::format("popq %{}\n", pick(reg));
    }

    std::string gen_code(int n) {
        decltype(&gen_pop) funcs[] = {
            gen_push,
            gen_lea,
            gen_mov,
            gen_cmp,
            gen_jcc,
            gen_call,
            gen_pop
        };
        // generate n valid x64 instructions
        std::string ret;
        for (int i = 0; i < n; ++i) {
            ret += pick(funcs)();
        }
        return ret;
    }
    std::string gen_junk(int n) {
        if (n == 0) {
            return "";
        }
        std::string ret = ".byte ";
        for (int i = 0; i < n - 1; ++i) {
            ret += std::format("0x{:02x}, ", rand() % 256);
        }
        ret += std::format("0x{:02x}\n", rand() % 256);
        return ret;
    }
    std::string gen_nop(int lv, int &label) {
        if (lv == 0) {
#if 0
            int c = rand() % 4;
            switch (c) {
            case 0:
                return ".byte 0x74, 0x03, 0x75, 0x01, 0xbf\n";
            case 1:
                return ".byte 0x0F, 0x1F, 0x44, 0xEB, 0x05, 0x75, 0xFC, 0x74, 0xFA, 0xB8\n";
            case 2:
                return ".byte 0xe8, 0x00, 0x00, 0x00, 0x00, 0x48, 0x83, 0x04, 0x24, 0x08, 0xc3, 0x48, 0xB9 \n";
            case 3:
                return ".byte 0x50, 0x48, 0x8d, 0x05, 0x09, 0x00, 0x00, 0x00, 0x48, 0x83, 0xc0, 0x02, 0x48, 0x87, 0x04, 0x24, 0xc3, 0x48, 0xB9\n";
            }
#endif
            return "";
        }
        auto chosen = rand() % 4;
        chosen = 1;
        switch (chosen) {
            case 0:
            {
/*
* j{x} {label}
* {nop}
* jn{x} {label}
* {code}
* {prefix}
* {label}:
* 
*/
                auto l1 = label++;
                auto nop1 = gen_nop(lv - 1, label);
                auto c = pick(jmpc);
                auto code1 = gen_code(rand() % 8 + 1);
                std::string ret = std::format(R"asm(
j{} {}f
pushfq
{}
popfq
jn{} {}f
{}
.byte 0x48, 0xb8
{}:
                )asm", c, l1, nop1, c, l1, code1, l1);
                return ret;
            }
            case 1:
            {
                /*
                * 
call 1f
.byte 0x48, 0x83
{nop}
jmp 2f
{code}
1:
add qword ptr [rsp], 2
{nop}
ret
.byte 0x48, 0xb8
2:
                */
                auto l1 = label++;
                auto l2 = label++;

                auto nop1 = gen_nop(lv - 1, label);
                auto nop2 = gen_nop(lv - 1, label);
                auto code1 = gen_code(rand() % 7 + 2);
                auto junkLen = rand() % 3;
                auto junk1 = gen_junk(junkLen);
                std::string ret = std::format(R"asm(
call {}f
.byte 0x48, 0x83
{}
{}
jmp {}f
{}
{}:
addq $${}, (%rsp)
{}
ret
.byte 0x48, 0xb8
{}:
                )asm", l1, junk1, nop1, l2, code1, l1, junkLen + 2,  nop2, l2);
                return ret;
            }
            case 2:
            {
/*
push rax
{nop}
lea rax, [rip + {l1}f]
{nop}
add rax, 0x2
{nop}
xchg   QWORD PTR [rsp],rax
{nop}
ret
{l1}:
{code}
.byte 0x48, 0x83
{l2}:
*/
                auto l1 = label++;
                auto l2 = label++;
                auto nop1 = gen_nop(lv - 1, label);
                auto nop2 = gen_nop(lv - 1, label);
                auto nop3 = gen_nop(lv - 1, label);
                auto nop4 = gen_nop(lv - 1, label);
                auto code1 = gen_code(rand() % 11 + 2);
                std::string ret = std::format(R"asm(
pushq %rax
{}
leaq {}f(%rip), %rax
{}
addq $({}f - {}f), %rax
{}
xchgq %rax, (%rsp)
{}
ret
{}:
{}
.byte 0x48, 0xb8
{}:
                )asm", nop1, l1, nop2, l2, l1, nop3, nop4, l1, code1, l2);
                return ret;
            }
            case 3: {
                std::string ret = gen_nop(lv - 1, label);
                ret += gen_nop(lv - 1, label);
                return ret;
            }
        }
        return  ".byte 0x90\n";
    }
}

namespace jmp::detail {
    
}

namespace {
    // Debug logging - outputs to stderr to avoid interfering with pipeline
    constexpr bool RSHIT_DEBUG = true;
    // Enable/disable actual code insertion (for debugging)
    constexpr bool RSHIT_INSERT_CODE = true;

    constexpr bool RSHIT_ENABLE_JMP = true;

    bool TestBr(llvm::BranchInst* BI) {
        auto& Ctx = BI->getContext();
        if (!BI->isConditional()) {
            if constexpr (RSHIT_DEBUG) {
                llvm::errs() << "Unconditional branch: " << BI->getSuccessor(0) << "\n";

                llvm::BlockAddress::get(BI->getSuccessor(0))->printAsOperand(llvm::errs(), true);
                
            }
            llvm::Type *VoidTy    = llvm::Type::getVoidTy(Ctx);
            llvm::Type *Int8Ty    = llvm::Type::getInt8Ty(Ctx);                // i8
            llvm::Type *Int8PtrTy = llvm::PointerType::getUnqual(Int8Ty);         // i8* (addrspace 0)
            auto VoidFT = llvm::FunctionType::get(VoidTy, {Int8PtrTy}, false);
            if constexpr (RSHIT_ENABLE_JMP){
                llvm::IRBuilder<> builder(Ctx);
                builder.SetInsertPoint(BI);
                int label = 0;
                auto jmp_rax = llvm::InlineAsm::get(VoidFT, std::format(R"asm(
                    {}
                    pushq $0
                    {}
                    ret
                    {}
                    .byte 0x48, 0xb8
                )asm", nop::detail::gen_nop(2, label), nop::detail::gen_nop(2, label), nop::detail::gen_code(8)), "r", true /*hasSideEffects*/, false);
                builder.CreateCall(jmp_rax->getFunctionType(), jmp_rax, {llvm::BlockAddress::get(BI->getSuccessor(0))});
                return true;
            }
        }
        return false;
    }
}
//-----------------------------------------------------------------------------
// Rshit implementation
//-----------------------------------------------------------------------------
// No need to expose the internals of the pass to the outside world - keep
// everything in an anonymous namespace.
namespace {
    // New PM implementation
    struct RandomShit : llvm::PassInfoMixin<RandomShit> {
        // Main entry point, takes IR unit to run the pass on (&F) and the
        // corresponding pass manager (to be queried if need be)
        llvm::PreservedAnalyses run(llvm::Function& F, llvm::FunctionAnalysisManager&) {
            bool changed = false;
            for (auto& BB : F) {
                for (auto& I : BB) {
                    bool insert = false;
                    switch (I.getOpcode()) {
                    case llvm::Instruction::Load:
                        if constexpr (RSHIT_DEBUG) {
                            llvm::errs() << "Load: " << I << "\n";
                        }
                        insert = true;
                        break;
                    case llvm::Instruction::Store:
                        if constexpr (RSHIT_DEBUG) {
                            llvm::errs() << "Store: " << I << "\n";
                        }
                        insert = true;
                        break;
                    case llvm::Instruction::Br:
                        if constexpr (RSHIT_DEBUG) {
                            llvm::errs() << "Br: " << I << "\n";
                        }
                        insert = true;
                        if (TestBr(llvm::dyn_cast<llvm::BranchInst>(&I))){
                            insert = false;
                        }
                        break;
                    case llvm::Instruction::Call:
                        if constexpr (RSHIT_DEBUG) {
                            llvm::errs() << "Call: " << I << "\n";
                        }
                        insert = true;
                        break;
                    case llvm::Instruction::CallBr:
                        if constexpr (RSHIT_DEBUG) {
                            llvm::errs() << "CallBr: " << I << "\n";
                        }
                        insert = true;
                        break;
                    }
                    if (!insert) {
                        continue;
                    }
                    if constexpr (RSHIT_INSERT_CODE) {
                        auto VoidFT = llvm::FunctionType::get(llvm::Type::getVoidTy(F.getContext()), false);
                        llvm::IRBuilder<> builder(I.getContext());
                        builder.SetInsertPoint(&I);
                        int label = 0;
                        // auto nop = llvm::InlineAsm::get(VoidFT, ".byte 0x74, 0x03, 0x75, 0x01, 0xbf", "", true /*hasSideEffects*/, false);
                        auto nop = llvm::InlineAsm::get(VoidFT, nop::detail::gen_nop(nop::detail::rand() % 4, label), "", true /*hasSideEffects*/, false);
                        builder.CreateCall(nop->getFunctionType(), nop);
                        changed = true;
                    }
                }
            }
            return changed ? llvm::PreservedAnalyses::none():  llvm::PreservedAnalyses::all();
        }

        // Without isRequired returning true, this pass will be skipped for functions
        // decorated with the optnone LLVM attribute. Note that clang -O0 decorates
        // all functions with optnone.
        static bool isRequired() { return true; }
    };
} // namespace


namespace rshit {
    llvm::PassPluginLibraryInfo getPluginInfo() {
        return { LLVM_PLUGIN_API_VERSION, "KmlObfs", LLVM_VERSION_STRING,
            [](llvm::PassBuilder& PB) {
                 PB.registerPipelineParsingCallback([](llvm::StringRef Name, llvm::FunctionPassManager& FPM, llvm::ArrayRef<llvm::PassBuilder::PipelineElement>) {
                    if (Name == "rshit") {
                        FPM.addPass(RandomShit());
                        return true;
                    }
                    return false;
                });
            }
        };
    }
}
extern "C" LLVM_ATTRIBUTE_WEAK llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
    return rshit::getPluginInfo();
}