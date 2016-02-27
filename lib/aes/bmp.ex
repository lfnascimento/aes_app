defmodule AES.Bmp do
  use Bitwise
  @constant_matrix [[2, 3, 1, 1],
        [1, 2, 3, 1],
        [1, 1, 2, 3],
        [3, 1, 1, 2]
      ]

  @inv_mxc_matrix [[14, 11, 13, 9],
                   [9, 14, 11, 13],
                   [13, 9, 14, 11],
                   [11, 13, 9, 14]
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

  def decode_image(file_name) do
    case File.read(file_name) do
      {:ok, binary} -> bmp_parse_decode(binary)
      _ -> IO.puts "Couldn't open #{file_name}"
    end
  end

  defp bmp_parse(<< header :: binary-size(26), body :: binary >>) do
    {:ok, file} = File.open "encode_test.bmp", [:write]
    IO.binwrite file, header
    block_parse(body, file)
  end

  defp bmp_parse_decode(<< header :: binary-size(26), body :: binary >>) do
    {:ok, file} = File.open "decode_test.bmp", [:write]
    IO.binwrite file, header
    block_decode(body, file)
  end

  defp add_round_key(number) do
    #<< key :: size(128) >> = "luisfernando1234"
    << key :: size(128) >> = "0123456789abcdef"
    bxor(number, key)
  end

  defp to_aes_matrix(list) do
    matrix = Enum.chunk(list, 4)
    #Matrix.transpose(matrix)
  end

  defp list_to_aes_matrix(list) do
    Enum.chunk(list, 4)
  end

  defp to_aes_matrix_trs(list) do
    matrix = Enum.chunk(list, 4)
    Matrix.transpose(matrix)
  end

  defp matrix_flatten(matrix) do
    List.flatten(matrix)
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

  defp list_to_bin(list) do
    :erlang.list_to_binary(list)
  end

  def mix_columns(matrix) do
    mt = Matrix.transpose(matrix)
    matrix_multiplicated = Enum.map(mt,
      fn(c) -> Matrix.mult([c], @constant_matrix) end)
    mf = Enum.map(matrix_multiplicated, fn(e) -> List.flatten(e) end)
    m256 = Enum.map(mf, fn(r) -> Enum.map(r, fn(e) -> rem(e, 256) end )
                            end )
    m256
  end

  def sub_bytes(bin_list) do
    int_list = bin_list_to_integer_list(bin_list)
    Enum.map(int_list, fn(position) -> Enum.at(Sbox.sbox, position) end)
  end

  defp bin_list_to_integer_list(bin_list) do
    Enum.map(bin_list, fn(e) -> << int :: size(8) >> = e; int end)
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

  def shift_row(matrix) do
    #IO.inspect matrix
    list_shifted = shift(matrix, 0)
    list_to_aes_matrix(list_shifted)
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

  def initial_round(bin_number) do
    add_round_key(bin_number)
  end

  defp round(bin_number, r) when r > 1 do
     bin_number_encode = bin_number |> integer_to_bin
      |> block_byte_to_list |> sub_bytes |> to_aes_matrix |> shift_row
      ##  |> to_aes_matrix
      ##   |> mix_columns
          |> list_to_bin |> bin_to_integer
            |> add_round_key

  ###  bin_number_encode = bin_number |> integer_to_bin
  ###   |> block_byte_to_list |> sub_bytes
  ###    |> to_aes_matrix |> shift_row
  ###      |> list_to_bin |> bin_to_integer
  ###        |> add_round_key

    round(bin_number_encode, r - 1)
  end

  defp round(final_bin_number, 1) do
     final_bin_number |> integer_to_bin
      |> block_byte_to_list |> sub_bytes |> to_aes_matrix |> shift_row
        |> list_to_bin |> bin_to_integer |> add_round_key
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


  defp inv_shift([row | rest], offset) do
    l_index = Enum.with_index(row)
    l_shifted = for {elem, index} <- l_index, do: {elem, rem(index + offset, 4)}
    l_index_sorted = Enum.map(l_shifted, fn(t) -> {e, i} = t;
                                if(i < 0, do: i = i + 4); {e, i} end)
    l_sorted = List.keysort(l_index_sorted, 1)
    l = Enum.map(l_sorted, fn(t) -> {e, _i} = t; e end)
    l ++ inv_shift(rest, offset + 1)
  end

  defp inv_shift([], _offset) do
    []
  end

  defp inv_shift_row(matrix) do
    inv_sr = inv_shift(matrix, 0)
  end

  defp inv_sub_bytes(bin_list) do
    int_list = bin_list_to_integer_list(bin_list)
    Enum.map(int_list, fn(position) -> Enum.at(Sbox.sbox_inv, position) end)
  end

  defp inv_mix_colums(bin_matrix) do
    ##int_matrix = Enum.map(bin_matrix, fn(e) -> Enum.map(e, fn(x) -> bin_list_to_integer_list(x)
    ##  end) end)
    int_matrix = Enum.map(bin_matrix, fn(list) -> bin_list_to_integer_list(list)
      end)
    #IO.inspect int_matrix
    matrix_multiplicated = Enum.map(int_matrix,
      fn(c) -> Matrix.mult([c], @inv_mxc_matrix) end)
    mf = Enum.map(matrix_multiplicated, fn(e) -> List.flatten(e) end)
    m256 = Enum.map(mf, fn(r) -> Enum.map(r, fn(e) -> rem(e, 256) end )
                            end )
    IO.inspect m256
    m256
  end

  defp decode_round(bin_number, r) when r > 1 do
     bin_number_decode = bin_number |> integer_to_bin |> block_byte_to_list
     |> to_aes_matrix |> inv_shift_row |> inv_sub_bytes |> list_to_bin
      |> bin_to_integer |> add_round_key |> integer_to_bin |> block_byte_to_list
      ##  |> to_aes_matrix
      ##  |> inv_mix_colums
          |> list_to_bin |> bin_to_integer

  ###      bin_number_decode = bin_number |> integer_to_bin |> block_byte_to_list
  ###       |> to_aes_matrix |> inv_shift_row |> inv_sub_bytes
  ###        |> list_to_bin
  ###          |> bin_to_integer |> add_round_key

      decode_round(bin_number_decode, r - 1)
  end

  defp decode_round(bin_number, 1) do
    bin_number |> integer_to_bin |> block_byte_to_list |> to_aes_matrix
       |> inv_shift_row |> inv_sub_bytes |> list_to_bin |> bin_to_integer
        |> add_round_key
  end

  defp block_decode(<< bin_number :: size(128), rest :: binary >>, file) do

    initial_block_decode = bin_number |> initial_round
    number_decode = decode_round(initial_block_decode, 10)
    block_decode = integer_to_bin(number_decode)


    IO.binwrite file, block_decode
    block_decode(rest, file)
  end

  defp block_decode(<< _, rest :: binary >>, file) do
    IO.binwrite file, rest
    File.close file
  end

  defp block_decode(_, file) do
    File.close file
  end

end
