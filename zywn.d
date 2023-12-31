import std.stdio;
import std.path;
import std.digest.crc;

class Path {}
class Tag {}


enum BranchState {
     ORDINARY,
     STAGED,
     STASHED,
     READY_TO_MERGE,
     DELETED,
}

class Branch {
    int branchId;
    string branchName;
    BranchState state;

    this(int branchId, string branchName) {
        this.branchId = branchId;
        this.branchName = branchName;
    }
}

class Commit {
    int commitId;
    string message;
    Tag tag;
    CRC32 checkSum;

    this(int commitId, string message) {
        this.commitId = commitId;
        this.message = message;
    }
}

class Repository {
    Branch[] branches;
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
        writeln("Staging changes:", changes);
    }

    void commit(string message) {
        CRC32 checkSum = calculateChecksum(); 
        Commit newCommit = new Commit(++currentCommitId, message);
        newCommit.checkSum = checkSum;
        commits ~= newCommit;

        writeln("Committing changes:", message);
    }

    void log() {
        writeln("Commit History:");
        foreach (commit; commits) {
            writeln("Commit ID:", commit.commitId);
            writeln("Message:", commit.message);
            writeln("Checksum:", commit.checkSum.to!string);
            writeln();
        }
    }

    private CRC32 calculateChecksum() {        
        return CRC32.init();
    }
}
