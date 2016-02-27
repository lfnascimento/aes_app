defmodule AES.BmpTest do
  use ExUnit.Case
  #doctest AES.Bmp

  setup do
    matrix = [[135, 242, 77, 151],
              [110, 76, 144, 236],
              [70, 231, 74, 195],
              [166, 140, 216, 149]]

    bin_number = 144166261073156674567442397401760019252

    {:ok, matrix: matrix, bin_number: bin_number}
  end

  test "InitialRoundStep", %{bin_number: bin_number} do
    number_expected = 122643902593943769440854651895415199314
    assert AES.Bmp.initial_round(bin_number) == number_expected
  end

  test "SubBytesStep" do
      sub_bytes_list = ["2", <<128>>, "1", <<224>>,
                        "C", "Z", "1", "7",
                        <<246>>, "0", <<152>>, "\a",
                        <<168>>, <<141>>, <<162>>, "4"]

      result_sub_bytes_list = [35, 205, 199, 225,
                               26, 190, 199, 154,
                               66, 4, 70, 197,
                               194, 93, 58, 24]

      assert AES.Bmp.sub_bytes(sub_bytes_list) == result_sub_bytes_list
    end

    test "ShiftRowStep", %{matrix: matrix} do

      matrix_shifted_row = [[135, 242, 77, 151],
                            [76, 144, 236, 110],
                            [74, 195, 70, 231],
                            [149, 166, 140, 216]]

      assert AES.Bmp.shift_row(matrix) == matrix_shifted_row
    end

    test "MixColumnsStep", %{matrix: matrix} do

      matrix_result = [[71, 64, 163, 76],
                       [55, 212, 112, 159],
                       [148, 228, 58, 66],
                       [237, 165, 166, 188]]

      assert AES.Bmp.mix_columns(matrix) == matrix_result
    end

end
