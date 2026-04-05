alias BlitzChat.Repo
alias BlitzChat.Accounts.User
alias BlitzChat.Chat.Room

# Users
{:ok, alice} =
  %User{}
  |> User.changeset(%{username: "alice", display_name: "Alice Chen"})
  |> Repo.insert(on_conflict: :nothing)

{:ok, bob} =
  %User{}
  |> User.changeset(%{username: "bob", display_name: "Bob Martinez"})
  |> Repo.insert(on_conflict: :nothing)

{:ok, charlie} =
  %User{}
  |> User.changeset(%{username: "charlie", display_name: "Charlie Park"})
  |> Repo.insert(on_conflict: :nothing)

# Rooms
for {name, desc} <- [
      {"General", "General discussion for the team"},
      {"Engineering", "Technical discussions and code reviews"},
      {"Random", "Off-topic conversations and fun stuff"}
    ] do
  %Room{}
  |> Room.changeset(%{name: name, description: desc, created_by: alice.id})
  |> Repo.insert(on_conflict: :nothing)
end

IO.puts("Seeds inserted: 3 users, 3 rooms")
