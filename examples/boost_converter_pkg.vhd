------------------------------------------------------------------------
-- boost_converter_pkg : an averaged boost converter model as a
-- microprogram, one Euler step of the inductor current i and the
-- capacitor voltage u from the input voltage vin, the duty d (standing for
-- the switch's 1 - D), the load current and the inductor's resistance r :
--
--   vL <- -d * u + vin        ic <- d * i - load
--   vL <- -r * i + vL         u  <- ic * h/C + u
--   i  <- vL * h/L + i
--
-- It settles at i = load / d, u = (vin - r * i) / d. The program and its
-- data are written once, for an address map, and laid out and encoded for
-- a processor configuration with microprogram_assembler_pkg :
--
--   constant addresses : boost_converter_map := boost_converter_at(100);
--   program := place(program, 128,
--       schedule(config, boost_converter_step(addresses)) & mi(program_end));
--   data := encode_data(boost_converter_data(addresses,
--       boost_converter_example), config, 1024);
------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

    use work.microinstruction_pkg.all;
    use work.microprogram_assembler_pkg.all;

package boost_converter_pkg is

    -- the model's data ram addresses
    type boost_converter_map is record
        vin, duty, load, r, i_gain, u_gain, i, u : natural;
        -- intermediate results
        vl, ic : natural;
    end record;

    -- ten consecutive addresses from first, in the order above
    function boost_converter_at (first : natural) return boost_converter_map;

    function boost_converter_step (addresses : boost_converter_map) return microprogram;

    -- the model's parameters and its state, i_gain = h/L, u_gain = h/C
    type boost_converter_values is record
        vin, duty, load, r, i_gain, u_gain, i, u : real;
    end record;

    -- the example of ac_in_ac_out_lab_power_supply's test_processor v3
    constant boost_converter_example : boost_converter_values := (
        vin => 20.0, duty => 0.8, load => 0.0, r => 0.8,
        i_gain => 0.7 / 3.0, u_gain => 0.7 / 3.0, i => 0.0, u => 12.0);

    function boost_converter_data (addresses : boost_converter_map; values : boost_converter_values) return data_list;

end package boost_converter_pkg;

package body boost_converter_pkg is

    function boost_converter_at (first : natural) return boost_converter_map is
    begin
        return (vin => first, duty => first + 1, load => first + 2, r => first + 3,
            i_gain => first + 4, u_gain => first + 5, i => first + 6, u => first + 7,
            vl => first + 8, ic => first + 9);
    end boost_converter_at;

    function boost_converter_step (addresses : boost_converter_map) return microprogram is
    begin
        return (mi(neg_mpy_add , addresses.vl , addresses.duty , addresses.u      , addresses.vin)
               ,mi(mpy_sub     , addresses.ic , addresses.duty , addresses.i      , addresses.load)
               ,mi(neg_mpy_add , addresses.vl , addresses.r    , addresses.i      , addresses.vl)
               ,mi(mpy_add     , addresses.u  , addresses.ic   , addresses.u_gain , addresses.u)
               ,mi(mpy_add     , addresses.i  , addresses.vl   , addresses.i_gain , addresses.i));
    end boost_converter_step;

    function boost_converter_data (addresses : boost_converter_map; values : boost_converter_values) return data_list is
    begin
        return ((addresses.vin, values.vin), (addresses.duty, values.duty), (addresses.load, values.load),
            (addresses.r, values.r), (addresses.i_gain, values.i_gain), (addresses.u_gain, values.u_gain),
            (addresses.i, values.i), (addresses.u, values.u));
    end boost_converter_data;

end package body boost_converter_pkg;
