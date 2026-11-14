#include <utility>

namespace cbor
{

class holder {
public:
    /** @brief Makes a holder from a value. */
    explicit holder(int v) noexcept(true)
        : value(std::move(v)), other(v ? 1 : 2)
    {
    }

    /** @brief Makes a holder from nothing. */
    holder() = default;

private:
    int value = 0;
    int other = 0;
};

}
