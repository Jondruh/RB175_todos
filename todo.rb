require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, ENV['SECRET_KEY']
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

helpers do
  def list_complete?(list)
    completed_count(list) == list[:todos].size && !list[:todos].empty?
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def completed_count(list)
    list[:todos].count { |todo| todo[:completed] }
  end
  
  def sort_todos(list)
    complete = []
    incomplete = []
    list[:todos].each_with_index do |todo, ind| 
      todo[:completed] ? complete << ind : incomplete << ind 
    end

    (incomplete + complete).each do |ind|
      yield(list[:todos][ind], ind)
    end
  end

  def sort_lists(lists)
    complete = []
    incomplete = []
    lists.each_with_index do |list, ind| 
      list_complete?(list) ? complete << ind : incomplete << ind 
    end

    (incomplete + complete).each do |ind|
      yield(lists[ind], ind)
    end
  end

end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters."
  end
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

# Renders a specific list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end


# Update an existing todo list
post "/lists/:id" do
  id = params[:id].to_i
  @list = session[:lists][id]
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list name has been changed."
    redirect "/lists/#{id}"
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end  
end

# Delete a list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].delete_at(id)

  session[:success] = "The list has been deleted."
  
  redirect "/lists"
end

# Remove a todo from a todo list
post "/lists/:list_id/todos/:id/destroy" do
  list_id = params[:list_id].to_i
  list = session[:lists][list_id]
  todo_id = params[:id].to_i

  todo_name = list[:todos][todo_id][:name]

  list[:todos].delete_at(todo_id)

  session[:success] = "'#{todo_name}' has been removed from the list."

  redirect "/lists/#{list_id}"
end

# Mark all todos for a list as complete
post "/lists/:id/complete_all" do
  list_id = params[:id].to_i
  list = session[:lists][list_id]
  
  list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = "All todos completed."
  redirect "/lists/#{list_id}"
end

# Update the status of a todo
post "/lists/:list_id/todos/:id" do
  list_id = params[:list_id].to_i
  list = session[:lists][list_id]

  todo_id = params[:id].to_i

  is_completed = params[:completed] == "true"
  list[:todos][todo_id][:completed] = is_completed

  session[:success] = "The todo has been updated."

  redirect "/lists/#{list_id}"
end

# Add a new todo item to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end