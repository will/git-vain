const std = @import("std");
const c = @import("c.zig");

const git = @import("../git.zig");

pub fn rebaseOptions(self: git.RebaseOptions) c.git_rebase_options {
    return .{
        .version = c.GIT_REBASE_OPTIONS_VERSION,
        .quiet = @intFromBool(self.quiet),
        .inmemory = @intFromBool(self.in_memory),
        .rewrite_notes_ref = if (self.rewrite_notes_ref) |s| s.ptr else null,
        .merge_options = mergeOptions(self.merge_options),
        .checkout_options = checkoutOptions(self.checkout_options),
        .signing_cb = @ptrCast(self.signing_cb),
        .payload = self.payload,
    };
}

pub fn diffOptions(self: git.DiffOptions) c.git_diff_options {
    return .{
        .version = c.GIT_DIFF_OPTIONS_VERSION,
        .flags = @bitCast(self.flags),
        .ignore_submodules = @intFromEnum(self.ignore_submodules),
        .pathspec = @bitCast(self.pathspec),
        .notify_cb = @ptrCast(self.notify_cb),
        .progress_cb = @ptrCast(self.progress_cb),
        .payload = self.payload,
        .context_lines = self.context_lines,
        .interhunk_lines = self.interhunk_lines,
        .id_abbrev = self.id_abbrev,
        .max_size = self.max_size,
        .old_prefix = self.old_prefix,
        .new_prefix = self.new_prefix,
    };
}

pub fn stashApplyOptions(self: git.StashApplyOptions) c.git_stash_apply_options {
    return .{
        .version = c.GIT_STASH_APPLY_OPTIONS_VERSION,
        .flags = @bitCast(self.flags),
        .checkout_options = checkoutOptions(self.checkout_options),
        .progress_cb = @ptrCast(self.progress_callback),
        .progress_payload = self.progress_payload,
    };
}

pub fn blobFilterOptions(self: git.BlobFilterOptions) c.git_blob_filter_options {
    return .{
        .version = c.GIT_BLOB_FILTER_OPTIONS_VERSION,
        .flags = @bitCast(self.flags),
        .commit_id = @ptrCast(self.commit_id),
    };
}

pub fn describeOptions(self: git.DescribeOptions) c.git_describe_options {
    return .{
        .version = c.GIT_DESCRIBE_OPTIONS_VERSION,
        .max_candidates_tags = self.max_candidate_tags,
        .describe_strategy = @intFromEnum(self.describe_strategy),
        .pattern = if (self.pattern) |slice| slice.ptr else null,
        .only_follow_first_parent = @intFromBool(self.only_follow_first_parent),
        .show_commit_oid_as_fallback = @intFromBool(self.show_commit_oid_as_fallback),
    };
}

pub fn describeFormatOptions(self: git.DescribeFormatOptions) c.git_describe_format_options {
    return .{
        .version = c.GIT_DESCRIBE_FORMAT_OPTIONS_VERSION,
        .abbreviated_size = self.abbreviated_size,
        .always_use_long_format = @intFromBool(self.always_use_long_format),
        .dirty_suffix = if (self.dirty_suffix) |slice| slice.ptr else null,
    };
}

pub fn filterOptions(self: git.FilterOptions) c.git_filter_options {
    return .{
        .version = c.GIT_FILTER_OPTIONS_VERSION,
        .flags = @bitCast(self.flags),
        .commit_id = @ptrCast(self.commit_id),
    };
}

pub fn repositoryInitOptions(self: git.RepositoryInitOptions) c.git_repository_init_options {
    return .{
        .version = c.GIT_REPOSITORY_INIT_OPTIONS_VERSION,
        .flags = self.flags.toInt(),
        .mode = self.mode.toInt(),
        .workdir_path = if (self.workdir_path) |slice| slice.ptr else null,
        .description = if (self.description) |slice| slice.ptr else null,
        .template_path = if (self.template_path) |slice| slice.ptr else null,
        .initial_head = if (self.initial_head) |slice| slice.ptr else null,
        .origin_url = if (self.origin_url) |slice| slice.ptr else null,
    };
}

pub fn hashsigOptions(self: git.HashsigOptions) c.git_hashsig_option_t {
    var ret: c.git_hashsig_option_t = 0;

    if (self.allow_small_files) {
        ret |= c.GIT_HASHSIG_ALLOW_SMALL_FILES;
    }

    switch (self.whitespace_mode) {
        .normal => ret |= c.GIT_HASHSIG_NORMAL,
        .ignore_whitespace => ret |= c.GIT_HASHSIG_IGNORE_WHITESPACE,
        .smart_whitespace => ret |= c.GIT_HASHSIG_SMART_WHITESPACE,
    }

    return ret;
}

pub fn mergeOptions(self: git.MergeOptions) c.git_merge_options {
    return .{
        .version = c.GIT_MERGE_OPTIONS_VERSION,
        .flags = @bitCast(self.flags),
        .rename_threshold = self.rename_threshold,
        .target_limit = self.target_limit,
        .metric = @ptrCast(self.metric),
        .recursion_limit = self.recursion_limit,
        .default_driver = if (self.default_driver) |ptr| ptr.ptr else null,
        .file_favor = @intFromEnum(self.file_favor),
        .file_flags = @bitCast(self.file_flags),
    };
}

pub fn fileStatusOptions(self: git.FileStatusOptions) c.git_status_options {
    return .{
        .version = c.GIT_STATUS_OPTIONS_VERSION,
        .show = @intFromEnum(self.show),
        .flags = @as(c_uint, @bitCast(self.flags)),
        .pathspec = @bitCast(self.pathspec),
        .baseline = @ptrCast(self.baseline),
    };
}

pub fn applyOptions(self: git.ApplyOptions) c.git_apply_options {
    return .{
        .version = c.GIT_APPLY_OPTIONS_VERSION,
        .delta_cb = @ptrCast(self.delta_cb),
        .hunk_cb = @ptrCast(self.hunk_cb),
        .payload = null,
        .flags = @bitCast(self.flags),
    };
}

pub fn applyOptionsWithUserData(comptime T: type, self: git.ApplyOptionsWithUserData(T)) c.git_apply_options {
    return .{
        .version = c.GIT_APPLY_OPTIONS_VERSION,
        .delta_cb = @ptrCast(self.delta_cb),
        .hunk_cb = @ptrCast(self.hunk_cb),
        .payload = self.payload,
        .flags = @bitCast(self.flags),
    };
}

comptime {
    if (@import("builtin").is_test) {
        var temp: u8 = undefined;
        _ = applyOptionsWithUserData(*u8, .{ .payload = &temp });
    }
}

pub fn blameOptions(self: git.BlameOptions) c.git_blame_options {
    return .{
        .version = c.GIT_BLAME_OPTIONS_VERSION,
        .flags = @bitCast(self.flags),
        .min_match_characters = self.min_match_characters,
        .newest_commit = @bitCast(self.newest_commit),
        .oldest_commit = @bitCast(self.oldest_commit),
        .min_line = self.min_line,
        .max_line = self.max_line,
    };
}

pub fn checkoutOptions(self: git.CheckoutOptions) c.git_checkout_options {
    return .{
        .version = c.GIT_CHECKOUT_OPTIONS_VERSION,
        .checkout_strategy = @bitCast(self.checkout_strategy),
        .disable_filters = @intFromBool(self.disable_filters),
        .dir_mode = self.dir_mode,
        .file_mode = self.file_mode,
        .file_open_flags = self.file_open_flags,
        .notify_flags = @bitCast(self.notify_flags),
        .notify_cb = @ptrCast(self.notify_cb),
        .notify_payload = self.notify_payload,
        .progress_cb = @ptrCast(self.progress_cb),
        .progress_payload = self.progress_payload,
        .paths = @bitCast(self.paths),
        .baseline = @ptrCast(self.baseline),
        .baseline_index = @ptrCast(self.baseline_index),
        .target_directory = if (self.target_directory) |ptr| ptr.ptr else null,
        .ancestor_label = if (self.ancestor_label) |ptr| ptr.ptr else null,
        .our_label = if (self.our_label) |ptr| ptr.ptr else null,
        .their_label = if (self.their_label) |ptr| ptr.ptr else null,
        .perfdata_cb = @ptrCast(self.perfdata_cb),
        .perfdata_payload = self.perfdata_payload,
    };
}

pub fn cherrypickOptions(self: git.CherrypickOptions) c.git_cherrypick_options {
    return .{
        .version = c.GIT_CHERRYPICK_OPTIONS_VERSION,
        .mainline = @intFromBool(self.mainline),
        .merge_opts = mergeOptions(self.merge_options),
        .checkout_opts = checkoutOptions(self.checkout_options),
    };
}

pub fn attributeOptions(self: git.AttributeOptions) c.git_attr_options {
    return .{
        .version = c.GIT_ATTR_OPTIONS_VERSION,
        .flags = attributeFlags(self.flags),
        .commit_id = @ptrCast(self.commit_id),
    };
}

pub fn attributeFlags(self: git.AttributeFlags) c_uint {
    var result: c_uint = 0;

    switch (self.location) {
        .file_then_index => {},
        .index_then_file => result |= c.GIT_ATTR_CHECK_INDEX_THEN_FILE,
        .index_only => result |= c.GIT_ATTR_CHECK_INDEX_ONLY,
    }

    if (self.extended.no_system) {
        result |= c.GIT_ATTR_CHECK_NO_SYSTEM;
    }

    if (self.extended.include_head) {
        result |= c.GIT_ATTR_CHECK_INCLUDE_HEAD;
    }

    if (self.extended.include_commit) {
        result |= c.GIT_ATTR_CHECK_INCLUDE_COMMIT;
    }

    return result;
}

pub fn worktreeAddOptions(self: git.WorktreeAddOptions) c.git_worktree_add_options {
    return .{
        .version = c.GIT_WORKTREE_ADD_OPTIONS_VERSION,
        .lock = @intFromBool(self.lock),
        .ref = @ptrCast(self.ref),
    };
}

pub fn revertOptions(self: git.RevertOptions) c.git_revert_options {
    return .{
        .version = c.GIT_REVERT_OPTIONS_VERSION,
        .mainline = @intFromBool(self.mainline),
        .merge_opts = mergeOptions(self.merge_options),
        .checkout_opts = checkoutOptions(self.checkout_options),
    };
}

// BUG: removed due to bitcast f
// pub fn fetchOptions(self: git.FetchOptions) c.git_fetch_options {
//     return .{
//         .version = c.GIT_FETCH_OPTIONS_VERSION,
//         .callbacks = @bitCast(self.callbacks),
//         .prune = @intFromEnum(self.prune),
//         .update_fetchhead = @intFromBool(self.update_fetchhead),
//         .download_tags = @intFromEnum(self.download_tags),
//         .proxy_opts = proxyOptions(self.proxy_opts),
//         .custom_headers = @bitCast(self.custom_headers),
//     };
// }
//
// pub fn cloneOptions(self: git.CloneOptions) c.git_clone_options {
//     return .{
//         .version = c.GIT_CHECKOUT_OPTIONS_VERSION,
//         .checkout_opts = checkoutOptions(self.checkout_options),
//         .fetch_opts = fetchOptions(self.fetch_options),
//         .bare = @intFromBool(self.bare),
//         .local = @intFromEnum(self.local),
//         .checkout_branch = if (self.checkout_branch) |b| b.ptr else null,
//         .repository_cb = @ptrCast(self.repository_cb),
//         .repository_cb_payload = self.repository_cb_payload,
//         .remote_cb = @ptrCast(self.remote_cb),
//         .remote_cb_payload = self.remote_cb_payload,
//     };
// }

pub fn proxyOptions(self: git.ProxyOptions) c.git_proxy_options {
    return .{
        .version = c.GIT_PROXY_OPTIONS_VERSION,
        .type = @intFromEnum(self.proxy_type),
        .url = if (self.url) |s| s.ptr else null,
        .credentials = @ptrCast(self.credentials),
        .payload = self.payload,
        .certificate_check = @ptrCast(self.certificate_check),
    };
}

// BUG: removed due to bitcast error
// pub fn createOptions(self: git.RemoteCreateOptions) c.git_remote_create_options {
//     return .{
//         .version = c.GIT_STATUS_OPTIONS_VERSION,
//         .repository = @ptrCast(self.repository),
//         .name = if (self.name) |ptr| ptr.ptr else null,
//         .fetchspec = if (self.fetchspec) |ptr| ptr.ptr else null,
//         .flags = @bitCast(self.flags),
//     };
// }
//
// pub fn pushOptions(self: git.PushOptions) c.git_push_options {
//     return .{
//         .version = c.GIT_PUSH_OPTIONS_VERSION,
//         .pb_parallelism = self.pb_parallelism,
//         .callbacks = @bitCast(self.callbacks),
//         .proxy_opts = proxyOptions(self.proxy_opts),
//         .custom_headers = @bitCast(self.custom_headers),
//     };
// }

pub fn pruneOptions(self: git.PruneOptions) c.git_worktree_prune_options {
    return .{
        .version = c.GIT_WORKTREE_PRUNE_OPTIONS_VERSION,
        .flags = @bitCast(self),
    };
}

comptime {
    std.testing.refAllDecls(@This());
}
