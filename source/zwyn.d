import std.stdio;
import std.path;
import std.file;
import std.array;
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

    void setContent(string newContent)
    {
        content = newContent;
    }
}

class DirContents
{
    DirEntry[] files;
    DirEntry[] directories;

    this(DirEntry[] entries)
    {
        foreach (e; entries)
        {
            if (e.isFile())
            {
                this.files ~= e;
            }
            else
                this.directories ~= e;
        }
    }

    DirEntry[] getFiles()
    {
        return this.files.dup;
    }

    DirEntry[] getDirectories()
    {
        return this.directories.dup;
    }
}

union Contents
{
    FileContents fileContents;
    DirContents dirContents;

    this(FileContents fileContents)
    {
        this.fileContents = fileContents;
    }

    this(DirContents dirContents)
    {
        this.dirContents = dirContents;
    }
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

    string[] chainWith(Path firstSegment, , ...)
    {
        return chainPath((this.value, firstSegment.value, args).array);
    }

    DirEntry[] readDir()
    {
        return dirEntries(this.value, SpanMode.shallow)
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
    CRC32 checkSum;
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
        auto targetBranch = branches.byValue!(Branch[int],
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
            // Handle error or return a default FileContents object
            return new FileContents("");
        }
    }

    void saveFileContents(Path filePath, FileContents fileContents)
    {
        std.file.write(filePath.value, fileContents.getContent());
    }
}
