#![cfg_attr(target_env = "polkavm", no_std)]
#![cfg_attr(target_env = "polkavm", no_main)]
#![allow(unexpected_cfgs)]

#[cfg(target_env = "polkavm")]
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}

use sha1::Digest;

#[cfg(not(target_env = "polkavm"))]
fn main() {
    let time = std::time::Instant::now();
    let calldata = include_bytes!("../../../../blobs/guest-program.bin");
    run(calldata.as_ptr().addr(), calldata.len());
    println!("INFO: Elapsed: {}s", time.elapsed().as_secs_f64());
}

#[cfg_attr(target_env = "polkavm", polkavm_derive::polkavm_export)]
fn run(calldata: usize, length: usize) -> u64 {
    let calldata = unsafe { core::slice::from_raw_parts(calldata as *const u8, length) };
    let mut hasher = sha1::Sha1::new();
    hasher.update(&calldata);
    let h = hasher.finalize();
    let h = h.as_slice();

    #[cfg(not(target_env = "polkavm"))]
    print!("INFO: Hash: ");
    #[cfg(not(target_env = "polkavm"))]
    for b in h {
        print!("{:02x}", b);
    }
    #[cfg(not(target_env = "polkavm"))]
    println!();

    let h = u64::from_be_bytes([h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]]);

    #[cfg(not(target_env = "polkavm"))]
    println!("INFO: Calculated hash: 0x{:x}", h);

    h
}
