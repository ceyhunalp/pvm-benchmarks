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
    run_native();
}

#[cfg_attr(target_env = "polkavm", polkavm_derive::polkavm_export)]
fn run(calldata: usize, length: usize) -> u64 {
    let calldata = unsafe { core::slice::from_raw_parts(calldata as *const u8, length) };
    let mut hasher = sha1::Sha1::new();
    hasher.update(&calldata);
    let h = hasher.finalize();
    let h = h.as_slice();

    #[cfg(not(target_env = "polkavm"))]
    // print!("INFO: Hash: ");
    #[cfg(not(target_env = "polkavm"))]
    // for b in h {
    //     print!("{:02x}", b);
    // }
    #[cfg(not(target_env = "polkavm"))]
    // println!();
    let h = u64::from_be_bytes([h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]]);

    #[cfg(not(target_env = "polkavm"))]
    // println!("INFO: Calculated hash: 0x{:x}", h);
    h
}

fn run_native() -> () {
    for (size, calldata) in [
        ("1K", &include_bytes!("../../../../blobs/sha1-1k.input")[..]),
        (
            "10K",
            &include_bytes!("../../../../blobs/sha1-10k.input")[..],
        ),
        (
            "100K",
            &include_bytes!("../../../../blobs/sha1-100k.input")[..],
        ),
        ("1M", &include_bytes!("../../../../blobs/sha1-1m.input")[..]),
        (
            "10M",
            &include_bytes!("../../../../blobs/sha1-10m.input")[..],
        ),
    ] {
        run(calldata.as_ptr().addr(), calldata.len());
        let time = std::time::Instant::now();
        for _ in 0..10 {
            run(calldata.as_ptr().addr(), calldata.len());
        }
        let elapsed = time.elapsed().as_secs_f64() / 10.0;
        println!("[{size}] Average time: {elapsed}s",);
    }
}
