defmodule SocialWeb.PostController do
  use SocialWeb.Web, :controller
  # alias Phoenix.Channel
  alias SocialWeb.{ Tools, Repo, Post, Comment }
  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    offset = params["count"]
    tag = params["tag"] || "0"
    posts = case tag do
      "0" -> Repo.all(from(p in Post, limit: 30, offset: ^offset , order_by: [desc: p.created_time]))
      "1" -> Repo.all(from(p in Post, limit: 30, offset: ^offset , order_by: [desc: p.trust_hot]))
      _ -> Repo.all(from(p in Post, where: p.tag == ^tag, offset: ^offset , order_by: [desc: p.created_time]))
    end
    |> Enum.map(fn(post) ->
      Map.take(post, [:id, :user_id, :user_name, :message, :attachments, :full_picture, :like_count, :comment_count, :link, :created_time, :tag])
    end)

    # posts_with_comments = Enum.into(posts, [], fn post -> #lấy comment của post
    #
    #   post_id = post.id
    #   comments = Repo.all(from(c in Comment, where: c.post_id == ^post_id, limit: 5))
    #   |> Enum.map(fn comment ->
    #     content = Map.take(comment, [:id, :user_id, :user_name, :message])
    #     comment_id = comment.id
    #     child_comments = Repo.all(from(c in Comment, where: c.parent_id == ^comment_id, limit: 2))
    #     |> Enum.map(fn child_comment ->
    #         Map.take(child_comment, [:id, :user_id, :user_name, :message])
    #       end)
    #     %{content: content, child_comment: child_comments}
    #    end)
    #
    #   %{post: post, comments: comments}
    # end)

    # data = %{post: post, %{comment: comment}}
    json conn, %{success: true, data: posts}
  end

  def get_comment(conn, params) do
    parent_id = params["parent_id"]
    offset = params["offset"]
    comments = Repo.all(from(c in Comment, where: c.parent_id == ^parent_id, offset: ^offset))
  end

  def get_post_by_tag(conn, params) do
    # 0: chưa phan loai
    # 1: mới nhất
    # 2: hot nhất
    tag_code = params["tag_code"]
    posts = case tag_code do
      "0" ->
        IO.inspect "0"
      "1" ->
        Repo.all(from(p in Post, order_by: [desc: p.created_time], limit: 5))
        |> Enum.map(fn(post) ->
          Map.take(post, [:id, :user_id, :user_name, :message, :full_picture, :like_count, :comment_count, :link, :created_time])
        end)
      "2" ->
        post_s = Repo.all(from(p in Post, order_by: [desc: p.trust_hot], limit: 3))
        post_s_id = Enum.map(post_s, fn(post) ->
          if post.tag != 2 do
            Ecto.Changeset.change(post, %{tag: 2})
            |> Repo.update
          end
          post.id
        end)
        Repo.all(from(p in Post, where: p.tag == 2, where: not p.id in ^post_s_id)) #thay đổi các post hot cũ thành tag = 0
        |> Enum.each(fn post ->
          Ecto.Changeset.change(post, %{tag: 0})
          |> Repo.update
        end)
        Enum.map(post_s, fn(post) ->
          Map.take(post, [:id, :user_id, :user_name, :message, :full_picture, :like_count, :comment_count, :link, :created_time, :tag])
        end)
      _ ->
        IO.inspect "ko tìm thấy tag post"
    end

    result_post = Enum.into(posts, [], fn post ->
        %{post: post}
      end
      )
    json conn, %{success: true, data: result_post}
  end

  # def trigger_load do
  #
  # end

  def get_one_post(conn, params) do
    post_id = params["post_id"]
    post = Repo.get(Post, post_id)
    |> Map.take([:id, :user_id, :user_name, :message, :attachments, :full_picture, :like_count, :comment_count, :link, :created_time, :tag])
    comments = Repo.all(from(c in Comment, where: c.post_id == ^post_id, order_by: [desc: c.created_time]))
    |> Enum.map(fn(comment) ->
      Map.take(comment, [:id, :post_id, :parent_id, :user_name, :created_time, :user_id, :lever, :message, :attachments, :like_count, :comment_count])
    end)
    # posts1 = Enum.map(posts, fn(post) ->
    #     comment_of_post = Enum.reduce(comments, [], fn(comment, acc) ->
    #       if comment["post_id"] == post["id"] do
    #         List.insert_at(acc, 0, comment)
    #       end
    #     end)
    #     Map.put_new(post, :comments, comment_of_post)
    #   end)
     new_comments = Enum.reduce(comments, [], fn(x, acc) ->
      child_comments = Enum.reduce(comments, [], fn(y, aco) ->
        if y.parent_id == x.id do
          aco = List.insert_at(aco, 0, y)
        else
          aco
        end
      end)
      comment_with_childs = if Enum.count(child_comments) != 0 do
        x = Map.put(x, :childs , child_comments)
        List.insert_at(acc, 0, x)
      else
        List.insert_at(acc, 0, x)
      end
    end)

    comments_with_childs = Enum.reduce(new_comments, [], fn(comment, acc) ->
      if comment.lever == 1 do
        List.insert_at(acc, 0, comment)
      else
        acc
      end
    end)

    user_id = case Mix.env() do
      :dev -> "1362834353783843"
      :prod -> "1165749846825629"
      # _ -> "1165749846825629"
    end

    update_comment = %{
      action: "group_post:update_for_post",
      user_id: user_id,
      post_id: post_id
    }
    Tools.enqueue_task(update_comment)
    #đoạn này gửi sang worker để load dữ liệu mới nhất của post
    json conn, %{sucess: true, data: %{posts: post, comments: comments_with_childs}}
  end

  def add_tag(conn, params) do
    post_id = params["post_id"]
    tag = params["tag"]
    post = Repo.get(Post, post_id)
    Ecto.Changeset.change(post, %{tag: tag})
    |> Repo.update
  end

end
