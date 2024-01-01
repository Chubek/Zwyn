import std.stdio;
import std.path;
import std.digest.crc;

enum SnapshotsDirectory = ".zywn";

enum PathKind {
    DIRECTORY,
    FILE,
}

class Path {
    PathKind kind;
    string value;

    this(PathKind kind, string value) {
	this.kind = kind;
        this.value = value;
    }

    bool opEquals(Path p) {
	return p.value == this.value;
    }
}

class Tag {
    string name;

    this(string name) {
        this.name = name;
    }
}


enum BranchState {
     ORDINARY,
     STAGED,
     STASHED,
     READY_TO_MERGE,
     DELETED,
}

class Snapshot {
    BranchState state;
    Path[] directories;
    Path[] files;
    ulong ndirs;
    ulong nfiles;
    Commit[] commits;
    bool orphan;

    this() {
        state = BranchState.ORDINARY;
        directories = new Path[](0);
        files = new Path[](0);
        commits = new Commit[](0);
    }

    void addDirectory(Path directory) {
        directories ~= directory;
    }

    void addFile(Path file) {
        files ~= file;
    }

    void removeDirectory(Path directory) {
	for (auto i = 0; i < ndirs; i++) {
		if (this.directories[i] == directory) {
			this.directories[i] = null;
		}
	}
    }

    void removeFile(Path file) {
       	for (auto i = 0; i < nfiles; i++) {
		if (this.files[i] == file) {
			this.files[i] = null;
		}
	}
    }

    void commitChanges(Commit commit) {
        commits ~= commit;
    }

}

class Branch {
    int branchId;
    int parentId;
    string branchName;
    Snapshot snapshot;

    this(int branchId, int parentId, string branchName) {
        this.branchId = branchId;
	this.parentId = parentId;
        this.branchName = branchName;
        this.snapshot = new Snapshot();
    }

    void addDirectory(Path directory) {
        snapshot.addDirectory(directory);
    }

    void addFile(Path file) {
        snapshot.addFile(file);
    }

    void removeDirectory(Path directory) {
        snapshot.removeDirectory(directory);
    }

    void removeFile(Path file) {
        snapshot.removeFile(file);
    }

    void commit(string message) {
        CRC32 checkSum = calculateChecksum();
        Commit newCommit = new Commit(snapshot.commits.length + 1, message);
        newCommit.checkSum = checkSum;
        snapshot.commitChanges(newCommit);

    }

}


class Commit {
    ulong commitId;
    string message;
    Tag tag;
    CRC32 checkSum;
    Path[] files;
    Path[] directories;

    this(ulong commitId, string message) {
        this.commitId = commitId;
        this.message = message;
    }
}

class Repository {
    Branch[int] branches;
    Commit[] commits;
    Path pathOnSystem;
    Path[] ignoreFiles;
    int currentCommitId;

    this(Path path, Path[] ignoreFiles) {
        commits = new Commit[](0);
        pathOnSystem = path;
        currentCommitId = 0;
    }

    void addChanges(string changes) {
    }

    void commit(string message) {
        CRC32 checkSum = calculateChecksum(); 
        Commit newCommit = new Commit(++currentCommitId, message);
        newCommit.checkSum = checkSum;
        commits ~= newCommit;

    }

}
