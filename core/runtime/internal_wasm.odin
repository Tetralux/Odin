package runtime

@(link_name="__umodti3")
umodti3 :: proc "c" (a, b: i128) -> i128 {
    return 0;
}


@(link_name="__udivmodti4")
udivmodti4 :: proc "c" (a, b: u128, rem: ^u128) -> u128 {
    return udivmod128(a, b, rem);
}

@(link_name="__udivti3")
udivti3 :: proc "c" (a, b: u128) -> u128 {
    return udivmodti4(a, b, nil);
}

@(link_name="__ashlti3")
@export __ashlti3 :: proc "c" (a, b: u128) -> u128 {
    return 0;
}