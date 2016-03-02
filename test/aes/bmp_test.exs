defmodule AES.BmpTest do
  use ExUnit.Case
  #doctest AES.Bmp

  setup do
    matrix = [[135, 242, 77, 151],
              [110, 76, 144, 236],
              [70, 231, 74, 195],
              [166, 140, 216, 149]]

    matrix_shifted_row = [[135, 242, 77, 151],
                          [76, 144, 236, 110],
                          [74, 195, 70, 231],
                          [149, 166, 140, 216]]

    bin_number = 144166261073156674567442397401760019252

    bin_number_aes_matrix = ['lfa1',
                          'uen2',
                          'ird3',
                          'sno4']

    {:ok, matrix: matrix, bin_number: bin_number, matrix_shifted_row:
      matrix_shifted_row, bin_number_matrix: bin_number_aes_matrix}
  end

  test "InitialRoundStep", %{bin_number: bin_number} do
    number_expected = 122643902593943769440854651895415199314
    assert AES.Bmp.initial_round(bin_number) == number_expected
  end

  test "SubBytesStep" do
      sub_bytes_matrix = [[50, 128, 49, 224],
                          'CZ17',
                          [246, 48, 152, 7],
                          [168, 141, 162, 52]]

      result_sub_bytes_matrix = [[35, 205, 199, 225],
                               [26, 190, 199, 154],
                               [66, 4, 70, 197],
                               [194, 93, 58, 24]]

      assert AES.Bmp.sub_bytes(sub_bytes_matrix) == result_sub_bytes_matrix
    end

    test "ShiftRowStep", %{matrix: matrix, matrix_shifted_row:
      matrix_shifted_row} do

      assert AES.Bmp.shift_row(matrix) == matrix_shifted_row
    end

    test "MixColumnsStep", %{matrix: matrix} do

      matrix_result = [[71, 64, 163, 76],
                       [55, 212, 112, 159],
                       [148, 228, 58, 66],
                       [237, 165, 166, 188]]

      assert AES.Bmp.mix_columns(matrix) == matrix_result
    end

    test "InverseShiftRowStep", %{matrix: matrix, matrix_shifted_row:
      matrix_shifted_row} do

      assert AES.Bmp.inv_shift_row(matrix_shifted_row) == matrix
    end

    test "InverseSubBytesStep" do
      sub_bytes_matrix = [[50, 128, 49, 224],
                          'CZ17',
                          [246, 48, 152, 7],
                          [168, 141, 162, 52]]

      result_sub_bytes_matrix = [[35, 205, 199, 225],
                               [26, 190, 199, 154],
                               [66, 4, 70, 197],
                               [194, 93, 58, 24]]

      assert AES.Bmp.inv_sub_bytes(result_sub_bytes_matrix) == sub_bytes_matrix
    end

    test "Binary Number to AES Matrix", %{bin_number: bin_number,
      bin_number_matrix: bin_number_aes_matrix} do

      assert AES.Bmp.bin_number_to_aes_matrix(bin_number) == bin_number_aes_matrix
    end

    test "AES Matrix to Binary Number",
      %{bin_number_matrix: bin_number_aes_matrix} do

      assert AES.Bmp.aes_matrix_to_bin_number(bin_number_aes_matrix) ==
        144088209136585352149831953730251943732
    end
end
