import std.stdio;
import std.path;
import std.file;
import std.algorithm.searching;
import std.array;
import std.digest.murmurhash;
import std.digest.crc;

enum SnapshotsImage = ".zwyn";

enum PathKind
{
    DIRECTORY,
    FILE,
}

class FileContents
{
    string content;

    this(string content)
    {
        this.content = content;
    }

    string getContent()
    {
        return content;
    }

    ubyte[4] getCrc32String()
    {
        return crc32Of(cast(ubyte[]) content);

    }
}


class Path
{
    PathKind kind;
    string value;
    bool removed;

    this(PathKind kind, string value)
    {
        this.kind = kind;
        this.value = value;
        this.removed = false;
    }

    void removeSelf()
    {
        removed = true;
    }

    bool pathExists()
    {
        return exists(value);
    }

    bool pathIsAbsolute()
    {
        return isAbsolute(value);
    }

    bool pathIsValid()
    {
        return isValidPath(value);
    }

    auto pathBaseName()
    {
        return baseName(value);
    }

    auto pathDirName()
    {
        return dirName(value);
    }

    auto pathStripExtension()
    {
        return stripExtension(value);
    }

    DirEntry[] readDir()
    {
	DirEntry[] entries;
	
	foreach (DirEntry e; dirEntries(value, SpanMode.shallow)) {
		entries ~= e;
	}
	
	return entries;
    }

    string readFile()
    {
        return readText(value);
    }

    bool opEquals(Path p)
    {
        return p.value == value;
    }
}

class WorkingDirectoryTree
{
    Path root;
    string[] ignoreList;

    this(Path root, string[] ignoreList)
    {
        this.root = root;
        this.ignoreList = ignoreList;
    }

    bool shouldIgnore(string entryName)
    {
        return any!(pattern => std.path.globMatch(entryName, pattern))(ignoreList);
    }

    void build()
    {
        foreach (entry; root.readDir())
        {
            if (shouldIgnore(entry.name))
                continue;

            if (entry.isFile())
                new FileNode(root.chainWith(entry.name)[0], root.readFile());
            else
                new DirectoryNode(root.chainWith(entry.name)[0]).build();
        }
    }

    void update(Path updatedPath)
    {
        auto node = findNode(updatedPath);
        if (node !is null)
            (updatedPath.pathExists()) ? node.update() : node.remove();
    }

    void commit(Path updatedPath, Commit commit)
    {
        auto node = findNode(updatedPath);
        if (node !is null)
            node.commit(commit);
    }

    Node findNode(Path path)
    {
        return findNodeRecursive(root, path);
    }

    Node findNodeRecursive(Node currentNode, Path path)
    {
        if (currentNode.path == path)
            return currentNode;

        if (currentNode is DirectoryNode(dirNode))
            return findNodeRecursive(dirNode.children.find!(child => findNodeRecursive(child,
                    path) !is null), path);

        return null;
    }

    ulong[2] getHash()
    {
	MurmurHash3!32 state;
	computeHashRecursive(root, state);
        return state.finalize();
    }

    void computeHashRecursive(Node currentNode, MurmurHash3!32 state)
    {
        state.put(cast(ubyte[]) currentNode.path.value);

        if (currentNode is DirectoryNode(dirNode))
            foreach (child; dirNode.children)
                computeHashRecursive(child, state);
        else if (currentNode is FileNode(fileNode))
                    state.put(cast(ubyte[]) fileNode.contents.getCrc32String());
    }
}

abstract class Node
{
    Path path;

    this(Path path)
    {
        this.path = path;
    }

    abstract void update();
    abstract void remove();
    abstract void commit(Commit commit);
}

class FileNode : Node
{
    FileContents contents;

    this(Path path, FileContents contents)
    {
        super(path);
        this.contents = contents;
    }

    override void update()
    {
        contents = path.readFile();
    }

    override void remove()
    {
        if (path.pathExists())
            path.removeSelf();
    }

    override void commit(Commit commit)
    {
        commit.files ~= path;
        commit.commitChanges(contents.getCrc32String());
    }
}

class DirectoryNode : Node
{
    Node[] children;

    this(Path path)
    {
        super(path);
        build();
    }

    void build()
    {
        foreach (entry; path.readDir())
        {
            if (entry.isFile())
                children ~= new FileNode(path.chainWith(entry.name)[0], path.readFile());
            else if (entry.isDirectory())
                children ~= new DirectoryNode(path.chainWith(entry.name)[0]).build();
        }
    }

    override void update()
    {
        build();
    }

    override void remove()
    {
        if (path.pathExists())
            path.removeSelf();
    }

    override void commit(Commit commit)
    {
        commit.directories ~= path;
        foreach (child; children)
            child.commit(commit);
    }
}

class Tag
{
    string name;

    this(string name)
    {
        this.name = name;
    }
}

class Commit
{
    ulong commitId;
    string message;
    Tag tag;
    ulong[2] checkSum;
    Path[] files;
    Path[] directories;
    FileNode[] fileSnapshots;
    DirectoryNode[] directorySnapshots;

    this(ulong commitId, string message)
    {
        this.commitId = commitId;
        this.message = message;
    }

    ulong[2] calculateMurmurHash()
    {
        MurmurHash128State state;
        state.initialize();
        state.put(cast(ubyte[]) commitId);
        state.put(cast(ubyte[]) message);

        foreach (file; files)
            state.put(cast(ubyte[]) file.value);

        foreach (dir; directories)
            state.put(cast(ubyte[]) dir.value);

        return state.finalize();
    }

    void addFile(Path file)
    {
        files ~= file;
    }

    void addDirectory(Path directory)
    {
        directories ~= directory;
    }

    void removeFile(Path file)
    {
        files = files.remove!(f => f == file);
    }

    void removeDirectory(Path directory)
    {
        directories = directories.remove!(d => d == directory);
    }

    void commitChanges(FileContents[] fileSnapshots, Path[] directorySnapshots)
    {
        this.fileSnapshots = fileSnapshots.dup;
        this.directorySnapshots = directorySnapshots.dup;
        checkSum = calculateMurmurHash();
    }
}

enum SnapshotState
{
    ORDINARY,
    STAGED,
    STASHED,
    READY_TO_MERGE,
    DELETED,
}

class Snapshot
{
    SnapshotState state;
    FileNode[] directories;
    DirectoryNode[] files;
    Commit[] commits;

    this()
    {
        state = SnapshotState.ORDINARY;
        directories = new FileNode[](0);
        files = new DirectoryNode[](0);
        commits = new Commit[](0);
    }

    void addDirectory(DirectoryNode directory)
    {
        directories ~= directory;
    }

    void addFile(FileNode file)
    {
        files ~= file;
    }

    void removeDirectory(DirectoryNode directory)
    {
        directories = directories.remove!(d => d == directory);
    }

    void removeFile(FileNode file)
    {
        files = files.remove!(f => f == file);
    }

    void commitChanges(Commit commit)
    {
        commits ~= commit;
    }
}

class HistoryEntry
{
    Commit commit;
    FileNode[] fileSnapshots;
    DirectoryNode[] directorySnapshots;
    ulong timestamp;

    this(Commit commit)
    {
        this.commit = commit;
        this.timestamp = Clock.currTime().msecs;
    }

    this(Commit commit, FileNode[] fileSnapshots, DirectoryNode[] directorySnapshots)
    {
        this.commit = commit;
        this.fileSnapshots = fileSnapshots.dup;
        this.directorySnapshots = directorySnapshots.dup;
        this.timestamp = Clock.currTime().msecs;
    }
}

class Branch
{
    int id;
    int parentId;
    string branchName;
    Repository repository;
    Snapshot snapshot;
    HistoryEntry[] history;

    this(int id, int parentId, string branchName, ref Repository repository)
    {
        this.id = id;
        this.parentId = parentId;
        this.branchName = branchName;
        this.snapshot = new Snapshot();
        this.repository = repository;
        this.history = new HistoryEntry[](0);
    }

    void commit(string message)
    {
        auto fileSnapshots = repository.snapshotFileContents();
        auto directorySnapshots = repository.snapshotDirectoryContents();

        auto newCommit = new Commit(++repository.currentCommitId, message);
        snapshot.commitChanges(newCommit);
        repository.commits ~= newCommit;

        history ~= new HistoryEntry(newCommit, fileSnapshots, directorySnapshots);
    }
}

class Repository
{
    Branch[int] branches;
    Commit[] commits;
    Path pathOnSystem;
    Path[] ignoreFiles;
    int currentCommitId;

    this(Path path, Path[] ignoreFiles)
    {
        commits = new Commit[](0);
        pathOnSystem = path;
        currentCommitId = 0;
    }

    Branch createBranch(string branchName)
    {
        int newBranchId = branches.length + 1;
        int parentId = 0;
        auto newBranch = new Branch(newBranchId, parentId, branchName, this);
        branches[newBranchId] = newBranch;
        return newBranch;
    }

    void switchBranch(string branchName)
    {
        auto targetBranch = branches.byValue!(Branch[int],
                string)(branch => branch.branchName == branchName);
        if (targetBranch !is null)
            currentCommitId = targetBranch.snapshot.commits.length;
    }

    void commit(string message)
    {
        auto checkSum = calculateChecksum();
        auto newCommit = new Commit(++currentCommitId, message);
        newCommit.checkSum = checkSum;
        commits ~= newCommit;
    }

    void viewCommitHistory()
    {
        foreach (commit; commits)
        {
            writeln("Commit ID: ", commit.commitId);
            writeln("Message: ", commit.message);
            writeln("Checksum: ", commit.checkSum);
            writeln();
        }
    }

    FileContents loadFileContents(Path filePath)
    {
        if (filePath.pathExists() && filePath.isFile())
            return new FileContents(cast(string) std.file.read(filePath.value));
        else
            return new FileContents("");
    }

    void saveFileContents(Path filePath, FileContents fileContents)
    {
        std.file.write(filePath.value, fileContents.getContent());
    }

    void viewBranchHistory(string branchName)
    {
        auto branch = branches.byValue!(Branch, string)(b => b.branchName == branchName);
        if (branch !is null)
        {
            foreach (entry; branch.history)
            {
                writeln("Timestamp: ", entry.timestamp);
                writeln("Commit ID: ", entry.commit.commitId);
                writeln("Message: ", entry.commit.message);
                writeln("Checksum: ", entry.commit.checkSum);
                writeln();
            }
        }
    }

    FileNode[] snapshotFileContents()
    {
        FileNode[] snapshots;
        foreach (file; snapshot.files)
        {
            snapshots ~= loadFileContents(file);
        }
        return snapshots;
    }

    DirectoryNode[] snapshotDirectoryContents()
    {
        DirectoryNode[] snapshots;
        foreach (dir; snapshot.directories)
        {
            snapshots ~= dir;
        }
        return snapshots;
    }

    CRC32 calculateChecksum()
    {
	MurmurHash3!32 state;

        state.put(cast(ubyte[]) commitId);
        state.put(cast(ubyte[]) message);

        foreach (file; files)
        {
            state.put(cast(ubyte[]) file.value);
        }

        foreach (dir; directories)
        {
            state.put(cast(ubyte[]) dir.value);
        }

        checkSum = hasher.finish();
    }
}
