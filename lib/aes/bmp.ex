defmodule AES.Bmp do
  use Bitwise

  def encode_image(file_name) do
    case File.read(file_name) do
      {:ok, binary} -> bmp_parse(binary)
      _ -> IO.puts "Couldn't open #{file_name}"
    end
  end

  defp bmp_parse(<< header :: binary-size(26), body :: binary >>) do
    {:ok, file} = File.open "encode_test.bmp", [:write]
    IO.binwrite file, header
    binary_block(body, file)
  end

  defp add_round_key(block) do
    << key :: size(128) >> = "luisfernando1234"
    xor = bxor(block, key)
  end

  defp to_aes_matrix(block) do
    matrix = Enum.chunk(block, 4)
    Matrix.transpose(matrix)
  end

  defp concat_zero_multiple_time(binary_block, n) when n <= 0 do
    binary_block <> <<>>
  end

  defp concat_zero_multiple_time(binary_block, n) do
    binary_block = "0" <> binary_block
    concat_zero_multiple_time(binary_block, n - 1 )
  end

  defp block_byte_to_list (block) do
    for <<b :: binary-size(1) <-  block >>, do: b
  end

  defp sub_bytes(block) do
    Enum.map(block, fn(e) -> << position :: size(8) >> = e; Enum.at(Sbox.sbox, position) end)
  end

  defp shift_row(block) do
    matrix = to_aes_matrix(block)

    [r0 | t] = matrix
    [r1 | t ] = t
      [a | rest] = r1
      l = [a]
      r1 = rest ++ l
    [r2 | t ] = t
      [a, b | rest] = r2
      l = [a, b]
      r2 = rest ++ l
    [r3 | t ] = t
      [a, b, c | rest] = r3
      l = [a, b, c]
      r3 = rest ++ l

      matrix_shifted = r0 ++ r1 ++ r2 ++ r3

      :erlang.list_to_binary(matrix_shifted)
  end

  defp binary_block(<< block :: size(128), rest :: binary >>, file) do
    number = add_round_key(block)
    block_hex = :erlang.integer_to_binary(number, 16)

    if byte_size(block_hex) < 32 do
        n = 32 - byte_size(block_hex)
        block_hex = concat_zero_multiple_time(block_hex, n)
        IO.inspect block_hex
    end
    {ok, block_byte} = Base.decode16(block_hex)

    block_cript = block_byte |> block_byte_to_list |> sub_bytes |> shift_row

    IO.binwrite file, block_cript
    binary_block(rest, file)
  end

  defp binary_block(<< _, rest :: binary >>, file) do
    IO.binwrite file, rest
    File.close file
  end

  defp binary_block(_, file) do
    File.close file
  end
end