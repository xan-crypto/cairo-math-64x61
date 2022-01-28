%lang starknet

from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import sign, abs_value, unsigned_div_rem, assert_not_zero
from math_64x61 import INT_PART, FRACT_PART, ONE, mul_fp, div_fp, sqrt_fp, exp_fp, assert_64x61

const PI = 7244019458077122842
const HALF_PI = 3622009729038561421

# Helper function to calculate Taylor series for sin
func _sin_fp_loop {range_check_ptr} (x: felt, i: felt, acc: felt) -> (res: felt):
    alloc_locals

    if i == -1:
        return (acc)
    end

    let (num) = mul_fp(x, x)
    tempvar div = (2 * i + 2) * (2 * i + 3) * FRACT_PART
    let (t) = div_fp(num, div)
    let (t_acc) = mul_fp(t, acc)
    let (next) = _sin_fp_loop(x, i - 1, ONE - t_acc)
    return (next)
end

# Calculates sin(x) with x in radians (fixed point)
@view
func sin_fp {range_check_ptr} (x: felt) -> (res: felt):
    alloc_locals

    let (_sign1) = sign(x) # extract sign
    let (abs1) = abs_value(x)
    let (_, x1) = unsigned_div_rem(abs1, 2 * PI)
    let (rem, x2) = unsigned_div_rem(x1, PI)
    local _sign2 = 1 - (2 * rem)
    let (acc) = _sin_fp_loop(x2, 6, ONE)
    let (res2) = mul_fp(x2, acc)
    local res = res2 * _sign1 * _sign2
    assert_64x61(res)
    return (res)
end

# Calculates cos(x) with x in radians (fixed point)
@view
func cos_fp {range_check_ptr} (x: felt) -> (res: felt):
    tempvar shifted = HALF_PI - x
    let (res) = sin_fp(shifted)
    return (res)
end

# Calculates tan(x) with x in radians (fixed point)
@view
func tan_fp {range_check_ptr} (x: felt) -> (res: felt):
    alloc_locals

    let (sinx) = sin_fp(x)
    let (cosx) = cos_fp(x)
    assert_not_zero(cosx)
    let (res) = div_fp(sinx, cosx)
    return (res)
end

# Calculates arctan(x) (fixed point)
# See https://stackoverflow.com/a/50894477 for range adjustments
@view
func atan_fp {range_check_ptr} (x: felt) -> (res: felt):
    alloc_locals

    const sqrt3_3 = 1331279082078542925 # sqrt(3) / 3
    const pi_6 = 1207336576346187140 # pi / 6
    const p_7 = 1614090106449585766 # 0.7
    
    # Calculate on positive values and re-assign later
    let (_sign) = sign(x)
    let (abs_x) = abs_value(x)

    # Invert value when x > 1
    let (_invert) = is_le(ONE, abs_x)
    local x1a_num = abs_x * (1 - _invert) + _invert * ONE
    tempvar x1a_div = abs_x * _invert + ONE - ONE * _invert
    let (x1a) = div_fp(x1a_num, x1a_div)

    # Account for lack of precision in polynomaial when x > 0.7
    let (_shift) = is_le(p_7, x1a)
    local b = sqrt3_3 * _shift + ONE - _shift * ONE
    local x1b_num = x1a - b
    let (x1b_div_2) = mul_fp(x1a, b)
    tempvar x1b_div = ONE + x1b_div_2
    let (x1b) = div_fp(x1b_num, x1b_div)
    local x1 = x1a * (1 - _shift) + x1b * _shift

    # 6.769e-8 maximum error
    const a1 = -156068910203
    const a2 = 2305874223272159097
    const a3 = -1025642721113314
    const a4 = -755722092556455027
    const a5 = -80090004380535356
    const a6 = 732863004158132014
    const a7 = -506263448524254433
    const a8 = 114871904819177193
    
    let (r8) = mul_fp(a8, x1)
    let (r7) = mul_fp(r8 + a7, x1)
    let (r6) = mul_fp(r7 + a6, x1)
    let (r5) = mul_fp(r6 + a5, x1)
    let (r4) = mul_fp(r5 + a4, x1)
    let (r3) = mul_fp(r4 + a3, x1)
    let (r2) = mul_fp(r3 + a2, x1)
    tempvar z1 = r2 + a1

    # Adjust for sign change, inversion, and shift
    tempvar z2 = z1 + (pi_6 * _shift)
    tempvar z3 = (z2 - (HALF_PI * _invert)) * (1 - _invert * 2)
    local res = z3 * _sign
    assert_64x61(res)
    return (res)
end

# Calculates arcsin(x) for -1 <= x <= 1 (fixed point)
# arcsin(x) = arctan(x / sqrt(1 - x^2))
@view
func asin_fp {range_check_ptr} (x: felt) -> (res: felt):
    alloc_locals

    let (_sign) = sign(x)
    let (x1) = abs_value(x)

    if x1 == ONE:
        return (HALF_PI * _sign)
    end

    let (x1_2) = mul_fp(x1, x1)
    let (div) = sqrt_fp(ONE - x1_2)
    let (atan_arg) = div_fp(x1, div)
    let (res_u) = atan_fp(atan_arg)
    return (res_u * _sign)
end

# Calculates arccos(x) for -1 <= x <= 1 (fixed point)
# arccos(x) = arcsin(sqrt(1 - x^2)) - arctan identity has discontinuity at zero
@view
func acos_fp {range_check_ptr} (x: felt) -> (res: felt):
    alloc_locals

    let (_sign) = sign(x)
    let (x1) = abs_value(x)
    let (x1_2) = mul_fp(x1, x1)
    let (asin_arg) = sqrt_fp(ONE - x1_2)
    let (res_u) = asin_fp(asin_arg)

    if _sign == -1:
        local res = PI - res_u
        assert_64x61(res)
        return (res)
    else:
        return (res_u)
    end
end