defmodule SocialWeb.Post do
  use SocialWeb.Web, :model

  @primary_key {:id, :string, autogenerate: false}
  schema "posts" do
    field :user_name,             :string
    field :message,               :string
    field :link,                  :string
    field :full_picture,          :string
    field :attachments,           {:array, :map}, default: []
    field :like_count,            :integer
    field :comment_count,         :integer
    field :status_type,           :map
    field :type,                  :string
    field :tag,                   :integer, default: 0
    field :trust_hot,             :integer, default: 0
    field :created_time,          Ecto.DateTime
    field :type_user,             :string

    belongs_to :user, SocialWeb.User, type: :string
    has_many :comment, SocialWeb.Comment

    timestamps
  end
end

### about tag  ###
# new -> 0
# hot -> 1
# general -> 2
# anser & question -> 3
# buy sell -> 4
# share community -> 5
# support pancake -> 6
####################
