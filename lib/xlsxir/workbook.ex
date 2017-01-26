defmodule Xlsxir.Book do
  @moduledoc """
  Documentation for Xlsxir.Book
  """
  defstruct  zip: nil, sheets: nil
  @type t :: %__MODULE__{zip: pid, sheets: map}
end



defmodule Xlsxir.Workbook do
  @moduledoc """
  Workbook supervisor.
  Supervises worksheet processes to hopefully allow for parallel xml parsing of
  sheets since they are each in their own process
  """
  @book_files [book: 'xl/workbook.xml', styles: 'xl/styles.xml', strings: 'xl/sharedStrings.xml']
  import SweetXml

  use Supervisor

  def init(args) do
    xlsx_file = Keyword.get(args, :path, nil)
    # returns a zip handle to be used by future calls, cant store in supervisor,
    # going to stash the handle in another process named Xlsxir.Zip

    {:ok, handle} = :zip.zip_open(String.to_charlist(xlsx_file)  ,[:memory])

    # reads the xml into string `book_xml`
    {:ok, {_file_name, book_xml }} = :zip.zip_get(@book_files[:book], handle)

    # not using these just yet, also place in their own process?
    #{:ok, {styles_name, styles_xml }} = :zip.zip_get(@book_files[:styles], handle)
    #{:ok, {strings_name, strings_xml }} = :zip.zip_get(@book_files[:strings], handle)

    children =
     book_xml
     |> xpath(~x"//sheets/./sheet"l, name: ~x"//./@name"s, id: ~x"//./@sheetId"i, rel_id: ~x"//./@r:id"s)
     |> Enum.map(fn s ->
        ws = struct(%Xlsxir.Sheet{path: String.to_charlist("worksheets/sheet#{s.id}.xml")}, s)
        worker(Xlsxir.Worksheet, [[ws: ws]], [id: ws.name])
     end)

     # create worker for zip handler
     zip_handler = worker(Xlsxir.Zip, [[zip: handle, path: xlsx_file]], [name: Xlsxir.Zip])

     # launch supervisor
     supervise([ zip_handler | children] , strategy: :one_for_one)
  end


  # could do more here, pass processed args as args to init,
  # rather than doing everything in init.
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end


  @doc """
  Grab all the worksheet details from respective supervised processes

  ## Examples
      iex> f = Path.join(:code.priv_dir(:xlsxir), "test_workbook.xlsx")
      iex> Xlsxir.load(f)
      iex> Xlsxir.Workbook.sheets
      [%Xlsxir.Sheet{data: [], id: 3, name: "sheet with space",
        path: 'worksheets/sheet3.xml', rel_id: "rId3"},
       %Xlsxir.Sheet{data: [], id: 2, name: "AnotherSheet",
        path: 'worksheets/sheet2.xml', rel_id: "rId2"},
       %Xlsxir.Sheet{data: [], id: 1, name: "FirstSheet",
        path: 'worksheets/sheet1.xml', rel_id: "rId1"}]
  """
  def sheets() do
    Supervisor.which_children(__MODULE__)
    |> Enum.filter_map(fn {_sheet_name, _sheet_pid, _, [child_mod]} -> child_mod == Xlsxir.Worksheet end,
      fn {_sheet_name, sheet_pid, _, _} -> Xlsxir.Worksheet.info(sheet_pid) end)
  end


  @doc """
  Load a workbook, ready to process sheets.

  ## Examples
      iex> f = Path.join(:code.priv_dir(:xlsxir), "test_workbook.xlsx")
      iex> Xlsxir.Workbook.load(f)
      {:ok, pid}

  """
  def load(workbook) do
    start_link([path: workbook])
  end
end
