namespace cbor
{

/**
 * @brief Adds one to @p value.
 *
 * The result is @p value plus one.
 * A value of the maximum wraps.
 *
 * @code{.example}
 * message: [1]
 * call: cbor::add_one(1)
 * result: 2
 * @endcode
 *
 * @retval overflow the value is the maximum
 * @retval not_found the item is missing
 * @return The sum.
 * @see cbor::other
 */
int add_one(int value);

}
