defmodule AES.Bmp do
  use Bitwise
  @constant_matrix [[2, 3, 1, 1],
        [1, 2, 3, 1],
        [1, 1, 2, 3],
        [3, 1, 1, 2]
      ]

  @small_key %{:key_size => 128, :rounds => 10}
  @medium_key %{:key_size => 192, :rounds => 12}
  @large_key %{:key_size => 256, :rounds => 14}

  def encode_image(file_name) do
    case File.read(file_name) do
      {:ok, binary} -> bmp_parse(binary)
      _ -> IO.puts "Couldn't open #{file_name}"
    end
  end

  defp bmp_parse(<< header :: binary-size(26), body :: binary >>) do
    {:ok, file} = File.open "encode_test.bmp", [:write]
    IO.binwrite file, header
    block_parse(body, file)
  end

  defp add_round_key(number) do
    << key :: size(128) >> = "luisfernando1234"
    bxor(number, key)
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

  defp mix_columns(matrix) do
    matrix_multiplicated = Enum.map(matrix,
      fn(c) -> Matrix.mult([c], @constant_matrix) end)
    mf = Enum.map(matrix_multiplicated, fn(e) -> List.flatten(e) end)
    matrix_256 = Enum.map(mf, fn(r) -> Enum.map(r, fn(e) -> rem(e, 256) end )
                            end )
    :erlang.list_to_binary(matrix_256)
  end

  defp sub_bytes(block) do
    Enum.map(block, fn(e) -> << position :: size(8) >> = e;
      Enum.at(Sbox.sbox, position) end)
  end

  defp shift([row | rest], offset) do
    l_index = Enum.with_index(row)
    l_shifted = for {elem, index} <- l_index, do: {elem, rem(index + offset, 4)}
    l_index_sorted = Enum.map(l_shifted, fn(t) -> {e, i} = t;
                                if(i < 0, do: i = i + 4); {e, i} end)
    l_sorted = List.keysort(l_index_sorted, 1)
    l = Enum.map(l_sorted, fn(t) -> {e, _i} = t; e end)
    l ++ shift(rest, offset - 1)
  end

  defp shift([], _offset) do
    []
  end

  defp shift_row(matrix) do
    shift(matrix, 0)
    #:erlang.list_to_binary(matrix_shifted)
  end

  defp bin_to_integer(<< number :: size(128) >>) do
    number
  end

  defp integer_to_bin(integer) do
    block_hex = :erlang.integer_to_binary(integer, 16)

    block_length = byte_size(block_hex)
    if block_length < 32 do
        n = 32 - block_length
        block_hex = concat_zero_multiple_time(block_hex, n)
    end

    {:ok, block_byte} = Base.decode16(block_hex)
    block_byte
  end

  defp initial_round(bin_number) do
    add_round_key(bin_number)
  end

  defp round(bin_number, r) when r > 0 do
    bin_number_encode = bin_number |> integer_to_bin
      |> block_byte_to_list |> sub_bytes |> to_aes_matrix |> shift_row
        |> to_aes_matrix |> mix_columns |> bin_to_integer |> add_round_key

    round(bin_number_encode, r - 1)
  end

  defp round(bin_number, 0) do
    bin_number
  end

  defp block_parse(<< bin_number :: size(128), rest :: binary >>, file) do

    initial_block_encode = bin_number |> initial_round
    number_encode = round(initial_block_encode, 10)
    block_encode = integer_to_bin(number_encode)

    IO.binwrite file, block_encode
    block_parse(rest, file)
  end

  defp block_parse(<< _, rest :: binary >>, file) do
    IO.binwrite file, rest
    File.close file
  end

  defp block_parse(_, file) do
    File.close file
  end
end
