#![cfg_attr(target_arch = "riscv32", no_std)]
#![cfg_attr(target_arch = "riscv32", no_main)]

// Source of the ROM: https://github.com/christopherpow/nes-test-roms/tree/97720008e51db15dd281a2a1e64d4c65cf1bca4c/nes15-1.0.0
// Licensed under a BSD-style license.
const ROM: &[u8] = core::include_bytes!("nes15-NTSC.nes");

extern crate alloc;

const HEAP_SIZE: usize = 512 * 1024;
struct GlobalAllocator(
    core::cell::UnsafeCell<picoalloc::Allocator<picoalloc::ArrayPointer<HEAP_SIZE>>>,
);

#[global_allocator]
static GLOBAL_ALLOCATOR: GlobalAllocator = {
    static mut ARRAY: picoalloc::Array<HEAP_SIZE> = picoalloc::Array([0; HEAP_SIZE]);

    GlobalAllocator(core::cell::UnsafeCell::new(picoalloc::Allocator::new(
        unsafe { picoalloc::ArrayPointer::new(&raw mut ARRAY) },
    )))
};

unsafe impl Sync for GlobalAllocator {}
unsafe impl alloc::alloc::GlobalAlloc for GlobalAllocator {
    unsafe fn alloc(&self, layout: alloc::alloc::Layout) -> *mut u8 {
        let Some(size) = picoalloc::Size::from_bytes_usize(layout.size()) else {
            return core::ptr::null_mut();
        };
        let Some(align) = picoalloc::Size::from_bytes_usize(layout.align()) else {
            return core::ptr::null_mut();
        };
        (&mut *self.0.get())
            .alloc(align, size)
            .map(|alloc| alloc.as_ptr())
            .unwrap_or(core::ptr::null_mut())
    }

    unsafe fn dealloc(&self, ptr: *mut u8, _layout: alloc::alloc::Layout) {
        let Some(ptr) = core::ptr::NonNull::new(ptr) else {
            return;
        };
        (&mut *self.0.get()).free(ptr)
    }
}

#[cfg(target_arch = "riscv32")]
const STACK_SIZE: usize = 4 * 1024;

#[cfg(target_arch = "riscv32")]
#[link_section = ".stack"]
#[used]
#[no_mangle]
pub static mut STACK: [u8; STACK_SIZE] = [0; STACK_SIZE];

#[cfg(target_arch = "riscv32")]
#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    println("Panic!");
    println(&alloc::format!("{}", info));

    unsafe {
        core::arch::asm!("unimp", options(noreturn));
    }
}

#[cfg(target_arch = "riscv32")]
fn println(slice: &str) {
    unsafe {
        core::arch::asm!(
            "li a0, 1",
            "ecall",
            out("a0") _,
            in("a1") slice.as_ptr(),
            in("a2") slice.len(),
        )
    }
}

#[cfg(not(target_arch = "riscv32"))]
fn println(slice: &str) {
    println!("{slice}");
}

#[cfg(target_arch = "riscv32")]
#[link_section = ".text.entry_point"]
#[unsafe(naked)]
#[no_mangle]
pub extern "C" fn entry_point() -> ! {
    core::arch::naked_asm!(
        ".8byte 0x00000000",
        "jal ra, {main}",
        "li a0, 0x45584954",
        "ecall",
        main = sym main_impl
    )
}

#[cfg(not(target_arch = "riscv32"))]
fn main() {
    main_impl();
}

extern "C" fn main_impl() {
    println("Starting...");
    let mut nes = VirtualNES {
        cycle: 0,
        frame: 0,
        state: nes::State::new(),
    };

    use nes::Interface;

    nes.load_rom(&ROM).unwrap();
    println("ROM loaded!");

    let count = 1;
    let mut checksum: u32 = 0;

    println("Starting loop...");
    for frame in 0..count {
        println("Starting frame...");
        nes.execute_for_a_frame().unwrap();
        let framebuffer = nes.framebuffer();
        for (index, pixel) in framebuffer.iter().enumerate() {
            checksum ^= u32::from(pixel.full_color_index()) << ((frame + index) % 16);
        }
        println("Frame finished!");
    }

    for address in 0x0000..=0x07ff {
        checksum ^= u32::from(nes.peek_memory(address)) << ((address % 4) * 8);
    }

    #[cfg(not(target_arch = "riscv32"))]
    {
        println!("Output: 0x{:08x}", checksum);
    }

    if checksum != 0xc2de0000 {
        unreachable!();
    }
}

struct VirtualNES {
    state: nes::State,
    cycle: u64,
    frame: u64,
}

impl nes::Context for VirtualNES {
    fn state(&self) -> &nes::State {
        &self.state
    }

    fn state_mut(&mut self) -> &mut nes::State {
        &mut self.state
    }

    fn on_cycle(&mut self) {
        self.cycle += 1;
    }

    fn on_frame(&mut self) {
        self.frame += 1;
    }

    fn on_audio_sample(&mut self, _sample: f32) {}
}
