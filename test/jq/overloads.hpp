#include <type_traits>

namespace cbor
{

struct box {
    /** @brief Gives the first form. */
    template <class T>
        requires std::is_integral_v<T>
    int get(T const value) const;

    /** @brief Gives the second form. */
    template <class T>
        requires std::is_floating_point_v<T>
    int get(T const value) const;

    /** @brief Gives the plain form. */
    int get() const;

};

}
