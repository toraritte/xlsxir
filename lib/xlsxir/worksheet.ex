defmodule Xlsxir.Sheet do
  defstruct name: nil, rel_id: nil, id: nil, path: nil, data: []
  @type t :: %__MODULE__{name: String.t, rel_id: String.t, id: integer, path: iolist, data: []}
end


defmodule Xlsxir.Worksheet do
  @moduledoc """
  Documentation for Xlsxir.Workbook
  """
  use GenServer

  def init(args) do
    {:ok, args}
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args[:ws])
  end

  @doc """
  Returns just the name of the worksheet

  ## Examples
      iex> Xlsxir.Worksheet.name(pid)
      "Sheet1"
  """
  def name(pid) do
    GenServer.call(pid, :name)
  end

  @doc """
  Returns sheet a Xlsxir.Sheet struct
  ## Examples
      iex> Xlsxir.Worksheet.info(pid)
        %Xlsxir.Sheet{}
  """
  def info(pid) do
    GenServer.call(pid, :info)
  end

  def handle_call(:info, _from, ws) do
    {:reply, ws, ws}
  end

  def handle_call(:name, _from, ws) do
    {:reply, ws.name, ws}
  end

end
