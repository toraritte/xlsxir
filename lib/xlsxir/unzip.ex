defmodule Xlsxir.Unzip do

  @moduledoc """
  Provides validation of accepted file types for file path, extracts required `.xlsx` contents to `./temp` and ultimately deletes the `./temp` directory and its contents.
  """

  defmodule A do
  # TODO: missing error wrappers at the endpoints
  def crucial_XMLs(path) do
    p =
      path
      |> String.to_char_list()

    {:ok, [_|zip_file_list]} = :zip.list_dir(p)

    zip_file_list
      |> Enum.reduce([], &to_needed_xmls/2)
      |> Enum.split_with(&String.match?(&1,~r/sheet/))
  end

  defp to_needed_xmls({:zip_file, fname, _,_,_,_}, acc) do
    re = ~r|^xl/(worksheets/sheet\|sharedStrings.xml\|styles.xml)|

    needed =
      fname
      |> to_string
      |> String.match?(re)

    case needed do
      true  -> [to_string(fname)|acc]
      false -> acc
    end
  end

  #                                             any :zip.extract/2 option
  def unzip_worksheets(path, indices \\ [], opts \\ [:memory])

  def unzip_worksheets(path, indices, opts) do
    {worksheets, others} = crucial_XMLs(path)

    chosen_worksheets = filter_worksheets(worksheets, indices)

    p = to_charlist(path)
    file_list =
      chosen_worksheets ++ others
      |> Enum.map(&to_charlist(&1))
    opts = [{:file_list, file_list}] ++ opts

    :zip.extract(p, opts)
  end

  defp filter_worksheets(worksheets, indices) do
      case indices == [] do
        true  ->
          worksheets
        false ->
          worksheets
          |> Enum.with_index
          |> Enum.filter_map(
              fn({_,i}) -> Enum.member?(indices,i) end,
              fn({v,_}) -> v end
            )
      end
    end

    def number_of_worksheets(path) do
      {worksheets,_} = crucial_XMLs(path)
      length(worksheets)
    end
  end
  {:ok,l } = A.unzip_worksheets("../../../agulyas_timesheet.xlsx") 

  @doc """
  Checks if given path is a valid file type and contains the requested worksheet, returning a tuple.

  ## Parameters

  - `path` - file path of a `.xlsx` file type in `string` format

  ## Example

         iex> path = "./test/test_data/test.xlsx"
         iex> Xlsxir.Unzip.validate_path_and_index(path, 0)
         {:ok, './test/test_data/test.xlsx'}

         iex> path = "./test/test_data/test.validfilebutnotxlsx"
         iex> Xlsxir.Unzip.validate_path_and_index(path, 0)
         {:ok, './test/test_data/test.validfilebutnotxlsx'}

         iex> path = "./test/test_data/test.xlsx"
         iex> Xlsxir.Unzip.validate_path_and_index(path, 100)
         {:error, "Invalid worksheet index."}
  """
  def validate_path_and_index(path, index) do
    path = String.to_char_list(path)

    case valid_extract_request?(path, index) do
      :ok              -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp valid_extract_request?(path, index) do
    case :zip.list_dir(path) do
      {:ok, file_list}  -> search_file_list(file_list, index)
      {:error, _reason} -> {:error, "Invalid file type."}
    end
  end

  defp search_file_list(file_list, index) do
    sheet   = 'xl/worksheets/sheet#{index + 1}.xml'
    results = file_list
              |> Enum.map(fn file ->
                   case file do
                     {:zip_file, ^sheet, _, _, _, _} -> :ok
                     _                               -> nil
                   end
                 end)

    if Enum.member?(results, :ok) do
      :ok
    else
      {:error, "Invalid worksheet index."}
    end
  end

  @doc """
  Checks if given path is a valid file type, returning a list of available worksheets.

  ## Parameters

  - `path` - file path of a `.xlsx` file type in `string` format

  ## Example

         iex> path = "./test/test_data/test.xlsx"
         iex> Xlsxir.Unzip.validate_path_all_indexes(path)
         {:ok, [0, 1, 2, 3, 4, 5, 6, 7, 8]}

         iex> path = "./test/test_data/test.zip"
         iex> Xlsxir.Unzip.validate_path_all_indexes(path)
         {:ok, []}
  """

  def validate_path_all_indexes(path) do
    path = String.to_char_list(path)
    case :zip.list_dir(path) do
      {:ok, file_list}  ->
        indexes = Enum.filter_map(file_list,
        fn file ->
          case file do
            {:zip_file, filename, _, _, _, _} ->
              filename |> to_string |> String.starts_with?("xl/worksheets/sheet")
            _ ->
              nil
          end
        end,
        fn {:zip_file, filename, _, _, _, _} ->
          index = filename
          |> to_string
          |> String.replace_prefix("xl/worksheets/sheet", "")
          |> String.replace_suffix(".xml", "")
          |> String.to_integer
          index - 1
        end)
        |> Enum.sort
        {:ok, indexes}
      {:error, _reason} -> {:error, "Invalid file type."}
    end
  end

  @doc """
  List of files contained in the requested `.xlsx` file to be extracted.

  ## Parameters

  - `index` - index of the `.xlsx` worksheet to be parsed

  ## Example

         iex> Xlsxir.Unzip.xml_file_list(0)
         ['xl/styles.xml', 'xl/sharedStrings.xml', 'xl/worksheets/sheet1.xml']
  """
  def xml_file_list(index) do
    [
     'xl/styles.xml',
     'xl/sharedStrings.xml',
     'xl/worksheets/sheet#{index + 1}.xml'
    ]
  end

  @doc """
  Extracts requested list of files from a `.zip` file to `./temp` and returns a list of the extracted file paths.

  ## Parameters

  - `file_list` - list containing file paths to be extracted in `char_list` format
  - `path` - file path of a `.xlsx` file type in `string` format

  ## Example
  An example file named `test.zip` located in './test_data/test' containing a single file named `test.txt`:

      iex> path = "./test/test_data/test.zip"
      iex> file_list = ['test.txt']
      iex> Xlsxir.Unzip.extract_xml_to_file(file_list, path)
      {:ok, ['temp/test.txt']}
      iex> File.ls("./temp")
      {:ok, ["test.txt"]}
      iex> Xlsxir.Unzip.delete_dir("./temp")
      :ok
  """
  def extract_xml_to_file(file_list, path) do
    path
    |> to_char_list
    |> :zip.extract([{:file_list, file_list}, {:cwd, 'temp/'}])
    |> case do
        {:error, reason}  -> {:error, reason}
        {:ok, []}         -> {:error, "Invalid File. Required XML files not found."}
        {:ok, files_list} -> {:ok, files_list}
       end
  end

  @doc """
  Deletes all files and directories contained in specified directory.

  ## Parameters

  - `dir` - list of directories to delete (default set for standard Xlsxir functionality)

  ## Example
  An example file named `test.zip` located in './test_data/test' containing a single file named `test.txt`:

      iex> path = "./test/test_data/test.zip"
      iex> file_list = ['test.txt']
      iex> Xlsxir.Unzip.extract_xml_to_file(file_list, path)
      {:ok, ['temp/test.txt']}
      iex> Xlsxir.Unzip.delete_dir("./temp")
      :ok
  """
  def delete_dir(dir \\ "./temp") do
    File.rm_rf(dir)
    :ok
  end

end
