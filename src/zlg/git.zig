const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

pub const path_list_separator = c.GIT_PATH_LIST_SEPARATOR;

const alloc = @import("alloc.zig");
pub const GitAllocator = alloc.GitAllocator;

const annotated_commit = @import("annotated_commit.zig");
pub const AnnotatedCommit = annotated_commit.AnnotatedCommit;

const attribute = @import("attribute.zig");
pub const Attribute = attribute.Attribute;
pub const AttributeOptions = attribute.AttributeOptions;
pub const AttributeFlags = attribute.AttributeFlags;

const blame = @import("blame.zig");
pub const Blame = blame.Blame;
pub const BlameHunk = blame.BlameHunk;
pub const BlameOptions = blame.BlameOptions;

const blob = @import("blob.zig");
pub const Blob = blob.Blob;
pub const BlobFilterOptions = blob.BlobFilterOptions;

const buffer = @import("buffer.zig");
pub const Buf = buffer.Buf;

const certificate = @import("certificate.zig");
pub const Certificate = certificate.Certificate;

const commit = @import("commit.zig");
pub const Commit = commit.Commit;
pub const RevertOptions = commit.RevertOptions;

const config = @import("config.zig");
pub const Config = config.Config;
pub const ConfigBackend = config.ConfigBackend;
pub const ConfigLevel = config.ConfigLevel;

const credential = @import("credential.zig");
pub const Credential = credential.Credential;
pub const CredentialType = credential.CredentialType;

const describe = @import("describe.zig");
pub const DescribeOptions = describe.DescribeOptions;
pub const DescribeFormatOptions = describe.DescribeFormatOptions;
pub const DescribeResult = describe.DescribeResult;

const diff = @import("diff.zig");
pub const Diff = diff.Diff;
pub const DiffLine = diff.DiffLine;
pub const DiffOptions = diff.DiffOptions;
pub const DiffPerfData = diff.DiffPerfData;
pub const DiffHunk = diff.DiffHunk;
pub const DiffDelta = diff.DiffDelta;
pub const ApplyOptions = diff.ApplyOptions;
pub const ApplyOptionsWithUserData = diff.ApplyOptionsWithUserData;
pub const ApplyOptionsFlags = diff.ApplyOptionsFlags;
pub const ApplyLocation = diff.ApplyLocation;
pub const DiffFile = diff.DiffFile;
pub const DiffFlags = diff.DiffFlags;

const errors = @import("errors.zig");
pub const GitError = errors.GitError;
pub const errorToCInt = errors.errorToCInt;
pub const DetailedError = errors.DetailedError;

const filter = @import("filter.zig");
pub const FilterMode = filter.FilterMode;
pub const FilterFlags = filter.FilterFlags;
pub const FilterOptions = filter.FilterOptions;
pub const Filter = filter.Filter;
pub const FilterList = filter.FilterList;

const handle = @import("handle.zig");
pub const Handle = handle.Handle;
pub const CloneOptions = handle.CloneOptions;

const hashsig = @import("hashsig.zig");
pub const Hashsig = hashsig.Hashsig;
pub const HashsigOptions = hashsig.HashsigOptions;

const index = @import("index.zig");
pub const Index = index.Index;
pub const IndexAddFlags = index.IndexAddFlags;

const indexer = @import("indexer.zig");
pub const Indexer = indexer.Indexer;
pub const IndexerProgress = indexer.IndexerProgress;
pub const IndexerOptions = indexer.IndexerOptions;

const mailmap = @import("mailmap.zig");
pub const Mailmap = mailmap.Mailmap;

const merge = @import("merge.zig");
pub const SimilarityMetric = merge.SimilarityMetric;
pub const FileFavor = merge.FileFavor;
pub const MergeOptions = merge.MergeOptions;

const message = @import("message.zig");
pub const MessageTrailerArray = message.MessageTrailerArray;

const net = @import("net.zig");
pub const Direction = net.Direction;

const notes = @import("notes.zig");
pub const Note = notes.Note;
pub const NoteIterator = notes.NoteIterator;

const object = @import("object.zig");
pub const Object = object.Object;
pub const ObjectType = object.ObjectType;

const odb = @import("odb.zig");
pub const Odb = odb.Odb;

const oid = @import("oid.zig");
pub const Oid = oid.Oid;
pub const OidShortener = oid.OidShortener;

const oidarray = @import("oidarray.zig");
pub const OidArray = oidarray.OidArray;

const pack = @import("pack.zig");
pub const PackBuilder = pack.PackBuilder;
pub const PackbuilderStage = pack.PackbuilderStage;

const patch = @import("patch.zig");
pub const Patch = patch.Patch;

const pathspec = @import("pathspec.zig");
pub const Pathspec = pathspec.Pathspec;
pub const PathspecMatchOptions = pathspec.PathspecMatchOptions;
pub const PathspecMatchList = pathspec.PathspecMatchList;

const proxy = @import("proxy.zig");
pub const ProxyOptions = proxy.ProxyOptions;

const rebase = @import("rebase.zig");
pub const Rebase = rebase.Rebase;
pub const RebaseOperation = rebase.RebaseOperation;
pub const RebaseOptions = rebase.RebaseOptions;

const refdb = @import("refdb.zig");
pub const Refdb = refdb.Refdb;

const reference = @import("reference.zig");
pub const Reference = reference.Reference;

const reflog = @import("reflog.zig");
pub const Reflog = reflog.Reflog;

const refspec = @import("refspec.zig");
pub const Refspec = refspec.Refspec;

// BUG: removed due to bitcast error
// const remote = @import("remote.zig");
// pub const Remote = remote.Remote;
// pub const RemoteAutoTagOption = remote.RemoteAutoTagOption;
// pub const RemoteCreateOptions = remote.RemoteCreateOptions;
// pub const FetchOptions = remote.FetchOptions;
// pub const PushOptions = remote.PushOptions;
// pub const RemoteCallbacks = remote.RemoteCallbacks;

const repository = @import("repository.zig");
pub const Repository = repository.Repository;
pub const StashApplyOptions = repository.StashApplyOptions;
pub const StashApplyProgress = repository.StashApplyProgress;
pub const StashFlags = repository.StashFlags;
pub const ResetType = repository.ResetType;
pub const RepositoryInitOptions = repository.RepositoryInitOptions;
pub const FileStatusOptions = repository.FileStatusOptions;
pub const RepositoryOpenOptions = repository.RepositoryOpenOptions;
pub const FileMode = repository.FileMode;
pub const FileStatus = repository.FileStatus;
pub const RevSpec = repository.RevSpec;
pub const CheckoutOptions = repository.CheckoutOptions;
pub const CherrypickOptions = repository.CherrypickOptions;

const revwalk = @import("revwalk.zig");
pub const RevWalk = revwalk.RevWalk;

const signature = @import("signature.zig");
pub const Signature = signature.Signature;
pub const Time = signature.Time;

const status_list = @import("status_list.zig");
pub const StatusList = status_list.StatusList;

const strarray = @import("strarray.zig");
pub const StrArray = strarray.StrArray;

const submodule = @import("submodule.zig");
pub const SubmoduleIgnore = submodule.SubmoduleIgnore;

const tag = @import("tag.zig");
pub const Tag = tag.Tag;

const transaction = @import("transaction.zig");
pub const Transaction = transaction.Transaction;

const transport = @import("transport.zig");
pub const Transport = transport.Transport;

const tree = @import("tree.zig");
pub const Tree = tree.Tree;
pub const TreeEntry = tree.TreeEntry;
pub const TreeBuilder = tree.TreeBuilder;

const worktree = @import("worktree.zig");
pub const Worktree = worktree.Worktree;
pub const WorktreeAddOptions = worktree.WorktreeAddOptions;
pub const PruneOptions = worktree.PruneOptions;

const writestream = @import("writestream.zig");
pub const WriteStream = writestream.WriteStream;

const git = @This();

/// Initialize global state. This function must be called before any other function.
/// *NOTE*: This function can called multiple times.
pub fn init() !git.Handle {
    if (internal.trace_log) log.debug("init called", .{});

    const number = try internal.wrapCallWithReturn("git_libgit2_init", .{});

    if (number > 1) {
        if (internal.trace_log) log.debug("{} ongoing initalizations without shutdown", .{number});
    }

    return git.Handle{};
}

pub fn availableLibGit2Features() LibGit2Features {
    return @as(LibGit2Features, @bitCast(c.git_libgit2_features()));
}

pub const LibGit2Features = packed struct {
    /// If set, libgit2 was built thread-aware and can be safely used from multiple threads.
    threads: bool = false,
    /// If set, libgit2 was built with and linked against a TLS implementation.
    /// Custom TLS streams may still be added by the user to support HTTPS regardless of this.
    https: bool = false,
    /// If set, libgit2 was built with and linked against libssh2. A custom transport may still be added by the user to support
    /// libssh2 regardless of this.
    ssh: bool = false,
    /// If set, libgit2 was built with support for sub-second resolution in file modification times.
    nsec: bool = false,

    z_padding: u28 = 0,

    pub fn format(
        value: LibGit2Features,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        return internal.formatWithoutFields(value, options, writer, &.{"z_padding"});
    }

    test {
        try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(LibGit2Features));
        try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(LibGit2Features));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
