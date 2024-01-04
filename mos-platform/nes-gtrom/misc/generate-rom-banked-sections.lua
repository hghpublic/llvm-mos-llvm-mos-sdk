-- Copyright (c) 2023 Adrian "asie" Siekierka
--
-- Licensed under the Apache License, Version 2.0 with LLVM Exceptions,
-- See https://github.com/llvm-mos/llvm-mos-sdk/blob/main/LICENSE for license
-- information.

local BANK_MAX = 15

function next_power_of_two(i)
    i = i - 1
    i = i | (i >> 1)
    i = i | (i >> 2)
    i = i | (i >> 4)
    i = i | (i >> 8)
    i = i | (i >> 16)
    i = i | (i >> 32)
    return i + 1
end

function printf(...)
    print(string.format(table.unpack({...})))
end

local args = {...}
if args[1] == "output" then
    for i=0,BANK_MAX do
        printf("  FULL(prg_rom_%d)", i)
    end
    return
end

print("/* Automatically generated by generate-rom-banked-sections.lua. */\n")

print("INPUT(reset.o)")

print([[

__prg_rom_fixed_lma = 0x008000;
]])

for i=0,BANK_MAX do
    printf("__prg_rom_%d_lma = 0x%02x8000;", i, i)
end
print("")

for i=0,BANK_MAX do
    printf("__prg_rom_%d_offset = 0x%06x;", i, i * 0x8000)
end
print("")

printf("MEMORY {")
print([[

  /* fixed section that will prefix all banks */
  fixed :     ORIGIN = __prg_rom_fixed_lma, LENGTH = 0x8000 - 0x6
]]);
printf("  /* PRG-ROM LMAs. */")
for i=0,BANK_MAX do
    local rom_size_kb = next_power_of_two(i + 1) * 32
    printf("  prg_rom_%d : ORIGIN = __prg_rom_%d_lma, LENGTH = __prg_rom_size >= %d ? 0x8000 - 0x6 : 0", i, i, rom_size_kb)
end
print([[  vectors : ORIGIN = 0x10000 - 0x6, LENGTH = 6

  /* CHR-ROM LMAs. */
  chr_rom_0   : ORIGIN = 0x01000000, LENGTH = __chr_rom_size >= 8    ? 0x2000 : 0
  chr_rom_1   : ORIGIN = 0x01002000, LENGTH = __chr_rom_size >= 16   ? 0x2000 : 0
}

/**
 * Alias "c_readonly" to fixed. Everything placed in this memory region
 * before the .prg_rom_fixed section is defined below (in file parsing order)
 * will become part of the fixed bank.
 *
 * So long as all the read-only C sections have been allocated to the
 * "c_readonly" region before this happens, the invariant of keeping all
 * default C section code in a fixed section is maintained.
 */
REGION_ALIAS("c_readonly", fixed)

SECTIONS {
  /* Define a fixed section at the beginning of PRG-ROM bank 0. */
  .prg_rom_fixed : {
    *(.prg_rom_fixed .prg_rom_fixed.*)
    __prg_rom_fixed_end = .;
    __prg_rom_fixed_size = __prg_rom_fixed_end - __prg_rom_0_lma;
  } >fixed

  /* Offset each non-fixed bank section's LMA by the fixed section. */
  /* This is accounted for in the custom output format. */]])

for i=0,BANK_MAX do
   local rom_size_kb = next_power_of_two(i + 1) * 32
   printf([[  __prg_rom%d_fixed_size = __prg_rom_size >= %d ? __prg_rom_fixed_size : 0;]], i, rom_size_kb);
end
print([[

  .fixed     : { *(.fixed     .fixed.*)     } >fixed
]])

for i=0,BANK_MAX do
    printf([[  .prg_rom_%d __prg_rom_%d_lma + __prg_rom%d_fixed_size : {
    *(.prg_rom_%d .prg_rom_%d.*)
  } >prg_rom_%d]], i, i, i, i, i, i)
    print("")
    printf([[  .dpcm_%d ((ABSOLUTE(.) & 0xffff) < 0xc000 ? __prg_rom_%d_lma + (__prg_rom_size >= %d ? 0x4000 : 0) : ALIGN(64)) : {
    __dpcm_%d_start = .;
    KEEP(*(.dpcm_%d .dpcm_%d.*))
  } >prg_rom_%d
  PROVIDE(__dpcm_%d_offset = ((__dpcm_%d_start & 0xffff) - 0xc000) >> 6);]], i, i, next_power_of_two(i + 1) * 32, i, i, i, i, i, i)
  print("")
end
print([[
  .chr_rom_0   : { KEEP(*(.chr_rom_0   .chr_rom_0.*)) }   >chr_rom_0
  .chr_rom_1   : { KEEP(*(.chr_rom_1   .chr_rom_1.*)) }   >chr_rom_1
}

__rom_poke_table = 0x5000;

SECTIONS {
  .vectors : { KEEP(*(.vectors)) } >vectors
}]])
