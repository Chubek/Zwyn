import std.stdio;
import std.path;
import std.file;
import std.array;
import std.digest.murmurhash;

enum SnapshotsImage = ".zwyn";

enum PathKind
{
    DIRECTORY,
    FILE,
}

class Path
{
    PathKind kind;
    Contents contents;
    string value;
    bool removed;

    this(PathKind kind, string value)
    {
        this.kind = kind;
        this.value = value;
        this.removed = false;
    }

    void read()
    {
        if (this.exists())
        {
            if (this.kind == PathKind.DIRECTORY)
            {
                auto dirContents = this.readDir();
                this.contents = Contents(dirContents);
            }
            else if (this.kind == PathKind.FILE)
            {
                auto fileContents = this.readFile();
                this.contents = Contents(fileContents);
            }
        }
    }

    void removeSelf(void)
    {
        this.removed = true;
    }

    bool exists(void)
    {
        return exists(this.value);
    }

    bool isAbsolute(void)
    {
        return isAbsolute(self.value);
    }

    bool isValid(void)
    {
        return isValidPath(self.value);
    }

    auto baseName(void)
    {
        return baseName(self.value);
    }

    auto dirName(void)
    {
        return dirName(self.value);
    }

    auto stripExtension(void)
    {
        return stripExtension(self.value);
    }

    string[] chainWith(Path firstSegment, string[] segments)
    {
        return chainPath((this.value, firstSegment.value ~ segments).array);
    }

    DirEntry[] readDir()
    {
        return dirEntries(this.value, SpanMode.shallow);
    }

    string readFile()
    {
        return readText(this.value);
    }

    bool opEquals(Path p)
    {
        return p.value == this.value;
    }
}

class WorkingDirectoryTree
{
    Path root;

    this(Path root)
    {
        this.root = root;
    }

    void build()
    {
        auto dirEntries = root.readDir();
        foreach (entry; dirEntries)
        {
            if (entry.isFile())
            {
                auto filePath = root.chainWith(entry.name)[0];
                auto fileContents = root.readFile();
                auto fileNode = new FileNode(filePath, fileContents);
            }
            else if (entry.isDirectory())
            {
                auto dirPath = root.chainWith(entry.name)[0];
                auto dirNode = new DirectoryNode(dirPath);
                dirNode.build();
            }
        }
    }

    void update(Path updatedPath)
    {
        auto node = findNode(updatedPath);
        if (node !is null)
        {
            if (updatedPath.exists())
            {
                node.update();
            }
            else
            {
                node.remove();
            }
        }
        else
        {

        }
    }

    void commit(Path updatedPath, Commit commit)
    {
        auto node = findNode(updatedPath);
        if (node !is null)
        {
            node.commit(commit);
        }
        else
        {

        }
    }

    Node findNode(Path path)
    {
        return this.findNodeRecursive(root, path);
    }

    Node findNodeRecursive(Node currentNode, Path path)
    {
        if (currentNode.path == path)
        {
            return currentNode;
        }

        if (currentNode is DirectoryNode)
        {
            auto dirNode = cast(DirectoryNode) currentNode;
            foreach (child; dirNode.children)
            {
                auto result = findNodeRecursive(child, path);
                if (result !is null)
                {
                    return result;
                }
            }
        }

        return null;
    }

    ulong[2] getHash()
    {
        MurmurHash128State state;
        state.initialize();
        computeHashRecursive(root, state);
        return state.finalize();
    }

    private void computeHashRecursive(Node currentNode, MurmurHash128State state)
    {
        state.update(cast(ubyte[]) currentNode.path.value);

        if (currentNode is DirectoryNode)
        {
            auto dirNode = cast(DirectoryNode) currentNode;
            foreach (child; dirNode.children)
            {
                computeHashRecursive(child, state);
            }
        }
        else if (currentNode is FileNode)
        {
            auto fileNode = cast(FileNode) currentNode;
            state.update(cast(ubyte[]) fileNode.contents.getCrc32String());
        }
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

        if (path.exists())
        {
            path.removeSelf();
        }
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
        auto dirEntries = path.readDir();
        foreach (entry; dirEntries)
        {
            if (entry.isFile())
            {
                auto filePath = path.chainWith(entry.name)[0];
                auto fileNode = new FileNode(filePath, filePath.readFile());
                children ~= fileNode;
            }
            else if (entry.isDirectory())
            {
                auto dirPath = path.chainWith(entry.name)[0];
                auto dirNode = new DirectoryNode(dirPath);
                children ~= dirNode;
            }
        }
    }

    override void update()
    {

        build();
    }

    override void remove()
    {

        if (path.exists())
        {
            path.removeSelf();
        }
    }

    override void commit(Commit commit)
    {

        commit.directories ~= path;
        foreach (child; children)
        {
            child.commit(commit);
        }
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
    string checkSum;
    Path[] files;
    Path[] directories;

    this(ulong commitId, string message)
    {
        this.commitId = commitId;
        this.message = message;
    }
}

enum BranchState
{
    ORDINARY,
    STAGED,
    STASHED,
    READY_TO_MERGE,
    DELETED,
}

class Snapshot
{
    BranchState state;
    Path[] directories;
    Path[] files;
    Commit[] commits;
    ulong ndirs;
    ulong nfiles;

    this()
    {
        state = BranchState.ORDINARY;
        directories = new Path[](0);
        files = new Path[](0);
        commits = new Commit[](0);
    }

    void addDirectory(Path directory)
    {
        directories ~= directory;
    }

    void addFile(Path file)
    {
        files ~= file;
    }

    void removeDirectory(Path directory)
    {
        for (auto i = 0; i < ndirs; i++)
        {
            if (this.directories[i] == directory)
            {
                this.directories[i].removeSelf();
            }
        }
    }

    void removeFile(Path file)
    {
        for (auto i = 0; i < nfiles; i++)
        {
            if (this.files[i] == file)
            {
                this.files[i].removeSelf();
            }
        }
    }

    void commitChanges(Commit commit)
    {
        commits ~= commit;
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
        auto newBranch = new Branch(newBranchId, parentId, branchName);
        branches[newBranchId] = newBranch;
        return newBranch;
    }

    void switchBranch(string branchName)
    {
        auto const targetBranch = branches.byValue!(Branch[int],
                string)(branch => branch.branchName == branchName);
        if (targetBranch !is null)
        {
            currentCommitId = targetBranch.snapshot.commits.length;
        }
    }

    void commit(string message)
    {
        CRC32 checkSum = calculateChecksum();
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
        if (filePath.exists() && filePath.isFile())
        {
            string fileContent = cast(string) std.file.read(filePath.value);
            return new FileContents(fileContent);
        }
        else
        {

            return new FileContents("");
        }
    }

    void saveFileContents(Path filePath, FileContents fileContents)
    {
        std.file.write(filePath.value, fileContents.getContent());
    }
}
