use polkavm::{Config, Engine, InterruptKind, Module, ProgramBlob, Reg};
use std::sync::Arc;

macro_rules! weights_io {
    (generate_code_impl
        $output:ident $model:ident
        $($inst:ident,)+
    ) => {
        let CostModel { $($inst,)+ } = $model;
        $({
            writeln!(&mut $output, "    {}: {},", stringify!($inst), $inst).unwrap();
        })+
    };

    (generate_json_impl
        $output:ident $model:ident
        $($inst:ident,)+
    ) => {
        let CostModel { $($inst,)+ } = $model;
        $({
            writeln!(&mut $output, "    \"{}\": {},", stringify!($inst), $inst).unwrap();
        })+
    };

    (generate_json $output:ident $model:ident) => {
        weights_io! {
            call generate_json_impl $output $model
        }
    };

    (generate_code $output:ident $model:ident) => {
        weights_io! {
            call generate_code_impl $output $model
        }
    };

    (model_from_map_impl $map:ident $model:ident $($inst:ident,)+) => {
        $(
            $model.$inst = $map.remove(stringify!($inst)).ok_or_else(|| format!("missing cost for: '{}'", stringify!($inst)))?;
        )+
    };

    (model_from_map $map:ident $model:ident) => {
        weights_io! {
            call model_from_map_impl $map $model
        }
    };

    (call
        $($args:ident)+
    ) => {
        weights_io! {
            $($args)+

            add_32,
            add_64,
            add_imm_32,
            add_imm_64,
            and,
            and_imm,
            and_inverted,
            branch_eq,
            branch_eq_imm,
            branch_greater_or_equal_signed,
            branch_greater_or_equal_signed_imm,
            branch_greater_or_equal_unsigned,
            branch_greater_or_equal_unsigned_imm,
            branch_greater_signed_imm,
            branch_greater_unsigned_imm,
            branch_less_or_equal_signed_imm,
            branch_less_or_equal_unsigned_imm,
            branch_less_signed,
            branch_less_signed_imm,
            branch_less_unsigned,
            branch_less_unsigned_imm,
            branch_not_eq,
            branch_not_eq_imm,
            cmov_if_not_zero,
            cmov_if_not_zero_imm,
            cmov_if_zero,
            cmov_if_zero_imm,
            count_leading_zero_bits_32,
            count_leading_zero_bits_64,
            count_set_bits_32,
            count_set_bits_64,
            count_trailing_zero_bits_32,
            count_trailing_zero_bits_64,
            div_signed_32,
            div_signed_64,
            div_unsigned_32,
            div_unsigned_64,
            ecalli,
            fallthrough,
            invalid,
            jump,
            jump_indirect,
            load_i16,
            load_i32,
            load_i8,
            load_imm,
            load_imm64,
            load_imm_and_jump,
            load_imm_and_jump_indirect,
            load_indirect_i16,
            load_indirect_i32,
            load_indirect_i8,
            load_indirect_u16,
            load_indirect_u32,
            load_indirect_u64,
            load_indirect_u8,
            load_u16,
            load_u32,
            load_u64,
            load_u8,
            maximum,
            maximum_unsigned,
            memset,
            minimum,
            minimum_unsigned,
            move_reg,
            mul_32,
            mul_64,
            mul_imm_32,
            mul_imm_64,
            mul_upper_signed_signed,
            mul_upper_signed_unsigned,
            mul_upper_unsigned_unsigned,
            negate_and_add_imm_32,
            negate_and_add_imm_64,
            or,
            or_imm,
            or_inverted,
            rem_signed_32,
            rem_signed_64,
            rem_unsigned_32,
            rem_unsigned_64,
            reverse_byte,
            rotate_left_32,
            rotate_left_64,
            rotate_right_32,
            rotate_right_64,
            rotate_right_imm_32,
            rotate_right_imm_64,
            rotate_right_imm_alt_32,
            rotate_right_imm_alt_64,
            sbrk,
            set_greater_than_signed_imm,
            set_greater_than_unsigned_imm,
            set_less_than_signed,
            set_less_than_signed_imm,
            set_less_than_unsigned,
            set_less_than_unsigned_imm,
            shift_arithmetic_right_32,
            shift_arithmetic_right_64,
            shift_arithmetic_right_imm_32,
            shift_arithmetic_right_imm_64,
            shift_arithmetic_right_imm_alt_32,
            shift_arithmetic_right_imm_alt_64,
            shift_logical_left_32,
            shift_logical_left_64,
            shift_logical_left_imm_32,
            shift_logical_left_imm_64,
            shift_logical_left_imm_alt_32,
            shift_logical_left_imm_alt_64,
            shift_logical_right_32,
            shift_logical_right_64,
            shift_logical_right_imm_32,
            shift_logical_right_imm_64,
            shift_logical_right_imm_alt_32,
            shift_logical_right_imm_alt_64,
            sign_extend_16,
            sign_extend_8,
            store_imm_indirect_u16,
            store_imm_indirect_u32,
            store_imm_indirect_u64,
            store_imm_indirect_u8,
            store_imm_u16,
            store_imm_u32,
            store_imm_u64,
            store_imm_u8,
            store_indirect_u16,
            store_indirect_u32,
            store_indirect_u64,
            store_indirect_u8,
            store_u16,
            store_u32,
            store_u64,
            store_u8,
            sub_32,
            sub_64,
            trap,
            xnor,
            xor,
            xor_imm,
            zero_extend_16,
        }
    };
}

use std::collections::BTreeMap;

fn deserialize_cost_model_from_map(
    mut map: BTreeMap<String, u32>,
) -> Result<polkavm::CostModel, String> {
    let mut cost_model = polkavm::CostModel::naive();
    weights_io! {
        model_from_map map cost_model
    }

    if !map.is_empty() {
        let extra_keys: Vec<_> = map.into_keys().map(|key| format!("'{}'", key)).collect();
        let extra_keys = extra_keys.join(", ");
        return Err(format!(
            "failed to deserialize cost model: extra keys: {extra_keys}"
        ));
    }

    Ok(cost_model)
}

fn main() {
    env_logger::init();

    let mut args = std::env::args().skip(1);
    let program_path = args.next().expect("missing program path");
    let data_path = args.next().expect("missing data path");

    let raw_blob = std::fs::read(&program_path).unwrap();
    let data = std::fs::read(&data_path).unwrap();
    let blob = ProgramBlob::parse(raw_blob[..].into()).unwrap();

    let mut is_first = true;

    for (name, cost_blob) in [
        ("L1-miss", &include_bytes!("../model-l1-miss.json")[..]),
        ("L2-miss", &include_bytes!("../model-l2-miss.json")[..]),
        ("L3-miss", &include_bytes!("../model-l3-miss.json")[..]),
    ] {
        println!("Using gas cost model: {name}");

        let cost_model;
        if let Some(map) = core::str::from_utf8(&cost_blob)
            .ok()
            .and_then(|blob| serde_json::from_str(blob).ok())
        {
            let map: BTreeMap<String, u32> = map;
            cost_model = deserialize_cost_model_from_map(map)
                .map_err(|error| format!("failed to parse the cost model for {name}: {error}"))
                .unwrap();
        } else {
            panic!("failed to parse the cost model for {name}");
        }

        let mut config = Config::from_env().unwrap();
        let cost_model = Arc::new(cost_model);
        config.set_allow_experimental(true);
        config.set_default_cost_model(Some(cost_model.into()));

        let engine = Engine::new(&config).unwrap();

        let mut config = polkavm::ModuleConfig::default();
        config.set_gas_metering(Some(polkavm::GasMeteringKind::Sync));
        config.set_aux_data_size(data.len().try_into().unwrap());
        let module = Module::from_blob(&engine, &config, blob.clone()).unwrap();
        let aux_address = module.memory_map().aux_data_address();

        let entry_point = module
            .exports()
            .find(|export| export == "run")
            .unwrap()
            .program_counter();

        println!("  Starting...");
        let instant = std::time::Instant::now();
        let mut instance = module.instantiate().unwrap();
        instance.set_next_program_counter(entry_point);
        instance.set_reg(Reg::RA, polkavm::RETURN_TO_HOST);
        instance.set_reg(Reg::SP, module.default_sp());
        instance.write_memory(aux_address, &data).unwrap();
        instance.set_reg(Reg::A0, u64::from(aux_address));
        instance.set_reg(Reg::A1, data.len() as u64);
        let initial_gas = 1000000000000000;
        instance.set_gas(initial_gas);

        loop {
            let interrupt_kind = instance.run().unwrap();
            match interrupt_kind {
                InterruptKind::Finished => break,
                _ => panic!("unexpected interruption: {interrupt_kind:?}"),
            }
        }

        let a0 = instance.reg(Reg::A0);
        println!("  Result: 0x{:x}", a0);

        let gas_used = initial_gas - instance.gas();
        println!("  Gas used: {}", gas_used);

        let elapsed = instant.elapsed().as_secs_f64();
        println!("  Initial run elapsed: {elapsed}s");

        core::mem::drop(instance);
        if is_first {
            let instant = std::time::Instant::now();
            is_first = false;
            for _ in 0..10 {
                let mut instance = module.instantiate().unwrap();
                instance.set_next_program_counter(entry_point);
                instance.set_reg(Reg::RA, polkavm::RETURN_TO_HOST);
                instance.set_reg(Reg::SP, module.default_sp());
                instance.write_memory(aux_address, &data).unwrap();
                instance.set_reg(Reg::A0, u64::from(aux_address));
                instance.set_reg(Reg::A1, data.len() as u64);
                let initial_gas = 1000000000000000;
                instance.set_gas(initial_gas);

                loop {
                    let interrupt_kind = instance.run().unwrap();
                    match interrupt_kind {
                        InterruptKind::Finished => break,
                        _ => panic!("unexpected interruption: {interrupt_kind:?}"),
                    }
                }
            }

            let elapsed = instant.elapsed().as_secs_f64() / 10.0;
            println!("  Elapsed on average: {elapsed}s");
        }

        println!();
    }
}
