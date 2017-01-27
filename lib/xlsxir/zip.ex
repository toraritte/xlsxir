
defmodule Xlsxir.Zip do
  @moduledoc """
  Holds onto zip handler for future reference, supervised by workbook
  """
  use GenServer

  def init(args) do
    {:ok, args}
  end

  def start_link(args) do

    GenServer.start_link(__MODULE__, %{zip: args[:zip], path: args[:path]}, name: __MODULE__)
  end


  def get_handle() do
    GenServer.call(__MODULE__, :zip)
  end

  def handle_call(:zip, _from, %{zip: zip} = state) do
    {:reply, zip, state}
  end

end
