#include <cstddef>

#define CBOR_ALWAYS_INLINE [[gnu::always_inline]]
#define CBOR_OWNER
#define CBOR_LIMIT_DEFAULT 7

namespace cbor
{

/** @brief A type that owns a thing. */
class CBOR_OWNER owner {
public:
    /** @brief Gives one. */
    CBOR_ALWAYS_INLINE static int one() { return 1; }
};

struct limits {
    /** @brief The most that is allowed. */
    static constexpr std::size_t most = CBOR_LIMIT_DEFAULT;
};

}
