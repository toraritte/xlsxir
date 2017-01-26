defmodule Xlsxir do
  use Application
  @moduledoc """
  Application module, probably not necessary...
  Not sure if necessary, can start with `Xlsxir.Workbook.load(args)`
  """

  @doc """
  Load a workbook, ready to process sheets.

  ## Examples
      iex> f = Path.join(:code.priv_dir(:xlsxir), "test_workbook.xlsx")
      iex> {:ok, workbook} = Xlsxir.load(f)

  """
  def load(workbook) do
    start(:normal, [path: workbook])
  end


  def start(_type, args) do
    Xlsxir.Workbook.start_link(args)
  end
end
