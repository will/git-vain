const c = @cImport({
    @cInclude("sys/sysctl.h");
});

fn sysctlGetU64(name: [:0]const u8) !u64 {
    var value: u64 = 0;
    var size: usize = @sizeOf(u64);
    const result = c.sysctlbyname(name.ptr, &value, &size, null, 0);
    if (result != 0) return error.SysctlFailed;
    return value;
}

pub fn getPerfCores() u8 {
    const answer = sysctlGetU64("hw.perflevel0.physicalcpu") catch 8;
    return @truncate(answer);
}
