import std.digest.murmurhash;


struct MurmurHash128State
{
    MurmurHash128 hasher;

    void initialize()
    {
        hasher = MurmurHash128();
    }

    void update(ubyte[] data)
    {
        hasher.put(data);
    }

    ulong[2] finalize()
    {
        return hasher.finish128();
    }
}
