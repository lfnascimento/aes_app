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
    block_encode(body, file)
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
    Matrix.transpose(matrix)
  end

  defp to_matrix(list) do
    matrix = Enum.chunk(list, 4)
  end

  defp matrix_flatten(matrix) do
    List.flatten(matrix)
  end

  defp list_to_aes_matrix(list) do
    Enum.chunk(list, 4)
    matrix = Enum.chunk(list, 4)
  end

  defp concat_zero_multiple_time(binary_block, n) when n <= 0 do
    binary_block <> <<>>
  end

  defp concat_zero_multiple_time(binary_block, n) do
    binary_block = "0" <> binary_block
    concat_zero_multiple_time(binary_block, n - 1 )
  end

  defp block_byte_to_list(block) do
    for <<b :: binary-size(1) <-  block >>, do: b
  end

  def block_byte_to_number_list(block) do
    for <<b :: 8 <-  block >>, do: b
  end

  defp list_to_bin(list) do
    :erlang.list_to_binary(list)
  end

  def mix_columns(matrix) do
    mt = Matrix.transpose(matrix)
    matrix_multiplicated = Enum.map(mt,
      fn(c) -> Matrix.mult([c], @constant_matrix) end)
    mf = Enum.map(matrix_multiplicated, fn(e) -> List.flatten(e) end)
    Enum.map(mf, fn(r) -> Enum.map(r, fn(e) -> rem(e, 256) end )
                            end )
  end

  def sub(matrix, sbox) do
    number_list = List.flatten(matrix)
    list_sub_bytes = Enum.map(number_list, fn(position)
                                              -> Enum.at(sbox, position) end)
    list_to_aes_matrix(list_sub_bytes)
  end

  def sub_bytes(matrix) do
    sub(matrix, Sbox.sbox)
  end

  defp bin_list_to_integer_list(bin_list) do
    Enum.map(bin_list, fn(e) -> << int :: size(8) >> = e; int end)
  end

  defp shift([row | rest], offset, side) do
    l_index = Enum.with_index(row)
    l_shifted = for {elem, index} <- l_index, do: {elem, rem(index + offset, 4)}
    l_index_sorted = Enum.map(l_shifted, fn(t) -> {e, i} = t;
                                if(i < 0, do: i = i + 4); {e, i} end)
    l_sorted = List.keysort(l_index_sorted, 1)
    l = Enum.map(l_sorted, fn(t) -> {e, _i} = t; e end)
    l ++ shift(rest, offset + (1 * side), side)
  end

  defp shift([], _offset, _side) do
    []
  end

  def shift_row(matrix) do
    left_side = -1
    list_shifted = shift(matrix, 0, left_side)
    list_to_aes_matrix(list_shifted)
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

  def bin_number_to_matrix(bin_number) do
    bin_number
    |> integer_to_bin
    |> block_byte_to_number_list
    |> to_matrix
  end

  def bin_number_to_aes_matrix(bin_number) do
    bin_number
    |> integer_to_bin
    |> block_byte_to_number_list
    |> to_aes_matrix
  end

  def aes_matrix_to_bin_number(matrix) do
    matrix |> matrix_flatten |> list_to_bin |> bin_to_integer
  end

  defp integer_to_matrix(number) do
    number
    |> integer_to_bin
    |> block_byte_to_number_list
    |> to_aes_matrix
    |> aes_matrix_to_bin_number
  end

  defp encode_round(bin_number, r) when r > 1 do
     bin_number_encode = bin_number
                         |> bin_number_to_matrix
                         |> sub_bytes
                         |> shift_row
                         ##  |> to_aes_matrix
                         ##   |> mix_columns
                         |> aes_matrix_to_bin_number
                         |> add_round_key

      encode_round(bin_number_encode, r - 1)
  end

  defp encode_round(final_bin_number, 1) do
     final_bin_number |> bin_number_to_matrix
                      |> sub_bytes
                      |> shift_row
                      |> aes_matrix_to_bin_number
                      |> add_round_key
  end

  defp block_encode(<< bin_number :: size(128), rest :: binary >>, file) do

    init_state =  bin_number
                  |> bin_number_to_aes_matrix

    initial_block_encode = init_state
                           |> aes_matrix_to_bin_number
                           |> initial_round

    number_encode = encode_round(initial_block_encode, 10)
    block_encode = number_encode
                   |> integer_to_matrix
                   |> integer_to_bin

    IO.binwrite file, block_encode
    block_encode(rest, file)
  end

  defp block_encode(<< _, rest :: binary >>, file) do
    IO.binwrite file, rest
    File.close file
  end

  defp block_encode(_, file) do
    File.close file
  end

  def inv_shift_row(matrix) do
    right_side = 1
    list_inv_sr = shift(matrix, 0, right_side)
    list_to_aes_matrix(list_inv_sr)
  end

  def inv_sub_bytes(matrix) do
    sub(matrix, Sbox.sbox_inv)
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
    Enum.map(mf, fn(r) -> Enum.map(r, fn(e) -> rem(e, 256) end )
                            end )
  end

  defp decode_round(bin_number, r) when r > 1 do
     bin_number_decode = bin_number
                         |> bin_number_to_matrix
                         |> inv_shift_row
                         |> inv_sub_bytes
                         |> aes_matrix_to_bin_number
                         |> add_round_key
                         ##  |> inv_mix_colums

      decode_round(bin_number_decode, r - 1)
  end

  defp decode_round(bin_number, 1) do
    bin_number |> bin_number_to_matrix
               |> inv_shift_row
               |> inv_sub_bytes
               |> aes_matrix_to_bin_number
               |> add_round_key
  end

  defp block_decode(<< bin_number :: size(128), rest :: binary >>, file) do

    init_state =  bin_number |> bin_number_to_aes_matrix

    initial_block_decode = init_state
                           |> aes_matrix_to_bin_number
                           |> initial_round

    number_decode = decode_round(initial_block_decode, 10)
    block_decode = number_decode
                   |> integer_to_matrix
                   |> integer_to_bin

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
