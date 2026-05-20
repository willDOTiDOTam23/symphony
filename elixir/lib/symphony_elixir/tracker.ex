defmodule SymphonyElixir.Tracker do
  @moduledoc """
  Adapter boundary for issue tracker reads and writes.
  """

  alias SymphonyElixir.Config
  alias SymphonyElixir.Linear.Issue

  @callback fetch_candidate_issues() :: {:ok, [term()]} | {:error, term()}
  @callback fetch_issues_by_states([String.t()]) :: {:ok, [term()]} | {:error, term()}
  @callback fetch_issue_states_by_ids([String.t()]) :: {:ok, [term()]} | {:error, term()}
  @callback create_comment(String.t(), String.t()) :: :ok | {:error, term()}
  @callback update_issue_state(String.t(), String.t()) :: :ok | {:error, term()}

  @spec fetch_candidate_issues() :: {:ok, [term()]} | {:error, term()}
  def fetch_candidate_issues do
    with {:ok, issues} <- adapter().fetch_candidate_issues() do
      {:ok, filter_routable_issues(issues)}
    end
  end

  @spec fetch_issues_by_states([String.t()]) :: {:ok, [term()]} | {:error, term()}
  def fetch_issues_by_states(states) do
    adapter().fetch_issues_by_states(states)
  end

  @spec fetch_issue_states_by_ids([String.t()]) :: {:ok, [term()]} | {:error, term()}
  def fetch_issue_states_by_ids(issue_ids) do
    adapter().fetch_issue_states_by_ids(issue_ids)
  end

  @spec create_comment(String.t(), String.t()) :: :ok | {:error, term()}
  def create_comment(issue_id, body) do
    adapter().create_comment(issue_id, body)
  end

  @spec update_issue_state(String.t(), String.t()) :: :ok | {:error, term()}
  def update_issue_state(issue_id, state_name) do
    adapter().update_issue_state(issue_id, state_name)
  end

  @spec adapter() :: module()
  def adapter do
    case Config.settings!().tracker.kind do
      "memory" -> SymphonyElixir.Tracker.Memory
      _ -> SymphonyElixir.Linear.Adapter
    end
  end

  @doc false
  @spec filter_routable_issues_for_test([term()]) :: [term()]
  def filter_routable_issues_for_test(issues) when is_list(issues), do: filter_routable_issues(issues)

  defp filter_routable_issues(issues) when is_list(issues) do
    tracker = Config.settings!().tracker

    Enum.filter(issues, fn
      %Issue{} = issue ->
        issue_matches_identifier_filter?(issue, tracker.issue_identifiers) and
          issue_matches_required_labels?(issue, tracker.required_labels) and
          issue_excludes_labels?(issue, tracker.excluded_labels)

      _ ->
        true
    end)
  end

  defp issue_matches_identifier_filter?(_issue, []), do: true

  defp issue_matches_identifier_filter?(%Issue{identifier: identifier}, allowed_identifiers)
       when is_binary(identifier) and is_list(allowed_identifiers) do
    identifier
    |> String.trim()
    |> String.upcase()
    |> then(&Enum.member?(allowed_identifiers, &1))
  end

  defp issue_matches_identifier_filter?(_issue, _allowed_identifiers), do: false

  defp issue_matches_required_labels?(_issue, []), do: true

  defp issue_matches_required_labels?(%Issue{} = issue, required_labels) when is_list(required_labels) do
    issue_labels = normalized_issue_label_set(issue)
    Enum.all?(required_labels, &MapSet.member?(issue_labels, &1))
  end

  defp issue_excludes_labels?(_issue, []), do: true

  defp issue_excludes_labels?(%Issue{} = issue, excluded_labels) when is_list(excluded_labels) do
    issue_labels = normalized_issue_label_set(issue)
    Enum.all?(excluded_labels, &(not MapSet.member?(issue_labels, &1)))
  end

  defp normalized_issue_label_set(%Issue{labels: labels}) when is_list(labels) do
    labels
    |> Enum.flat_map(fn
      label when is_binary(label) ->
        label = String.downcase(String.trim(label))
        if label == "", do: [], else: [label]

      _ ->
        []
    end)
    |> MapSet.new()
  end

  defp normalized_issue_label_set(_issue), do: MapSet.new()
end
