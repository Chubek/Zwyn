public struct MurmurHash128State
{
    ulong h1;
    ulong h2;
    ulong c1;
    ulong c2;
}

void MurmurHash128State.initialize()
{
    h1 = 0x9368e53c2f6af274UL;
    h2 = 0x586dcd208f7cd3fdUL;
    c1 = 0x87c37b91114253d5UL;
    c2 = 0x4cf5ad432745937fUL;
}

void MurmurHash128State.update(ubyte[] data)
{
    for (size_t i = 0; i + 15 < data.length; i += 16)
    {
        ulong k1 = data[i]      | (data[i + 1]  << 8)  | (data[i + 2]  << 16) | (data[i + 3]  << 24) |
                  (data[i + 4]  << 32) | (data[i + 5]  << 40) | (data[i + 6]  << 48) | (data[i + 7]  << 56);
        ulong k2 = data[i + 8]  | (data[i + 9]  << 8)  | (data[i + 10] << 16) | (data[i + 11] << 24) |
                  (data[i + 12] << 32) | (data[i + 13] << 40) | (data[i + 14] << 48) | (data[i + 15] << 56);

        k1 *= c1;
        k1 = (k1 << 31) | (k1 >> 33);
        k1 *= c2;
        h1 ^= k1;
        h1 = (h1 << 27) | (h1 >> 37);
        h1 += h2;
        h1 = h1 * 5 + 0x52dce729;

        k2 *= c2;
        k2 = (k2 << 33) | (k2 >> 31);
        k2 *= c1;
        h2 ^= k2;
        h2 = (h2 << 31) | (h2 >> 33);
        h2 += h1;
        h2 = h2 * 5 + 0x38495ab5;
    }
}

ulong[2] MurmurHash128State.finalize()
{
    ulong len = 0;
    h1 ^= len;
    h2 ^= len;

    h1 += h2;
    h2 += h1;

    h1 = fmix64(h1);
    h2 = fmix64(h2);

    h1 += h2;
    h2 += h1;

    return [h1, h2];
}

ulong fmix64(ulong k)
{
    k ^= k >> 33;
    k *= 0xff51afd7ed558ccdUL;
    k ^= k >> 33;
    k *= 0xc4ceb9fe1a85ec53UL;
    k ^= k >> 33;

    return k;
}

