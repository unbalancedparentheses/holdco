defmodule HoldcoWeb.CoreComponentsTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias HoldcoWeb.CoreComponents

  describe "flash/1" do
    test "renders info flash message from flash map" do
      assigns = %{flash: %{"info" => "Operation succeeded"}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash kind={:info} flash={@flash} />
        """)

      assert html =~ "Operation succeeded"
      assert html =~ "alert-info"
      assert html =~ "hero-information-circle"
    end

    test "renders error flash message from flash map" do
      assigns = %{flash: %{"error" => "Something went wrong"}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash kind={:error} flash={@flash} />
        """)

      assert html =~ "Something went wrong"
      assert html =~ "alert-error"
      assert html =~ "hero-exclamation-circle"
    end

    test "renders flash with a title" do
      assigns = %{flash: %{"info" => "Details here"}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash kind={:info} flash={@flash} title="Success" />
        """)

      assert html =~ "Success"
      assert html =~ "Details here"
      assert html =~ "font-semibold"
    end

    test "does not render when there is no flash message" do
      assigns = %{flash: %{}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash kind={:info} flash={@flash} />
        """)

      refute html =~ "alert"
    end

    test "renders inner_block content as flash message" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash kind={:info} flash={%{}}>Welcome Back!</CoreComponents.flash>
        """)

      assert html =~ "Welcome Back!"
      assert html =~ "alert-info"
    end

    test "renders with custom id" do
      assigns = %{flash: %{"error" => "Bad request"}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash kind={:error} flash={@flash} id="custom-flash" />
        """)

      assert html =~ ~s(id="custom-flash")
    end

    test "generates default id from kind" do
      assigns = %{flash: %{"info" => "Hello"}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash kind={:info} flash={@flash} />
        """)

      assert html =~ ~s(id="flash-info")
    end

    test "renders close button" do
      assigns = %{flash: %{"info" => "Closeable"}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash kind={:info} flash={@flash} />
        """)

      assert html =~ "hero-x-mark"
      assert html =~ ~s(aria-label="close")
    end
  end

  describe "button/1" do
    test "renders a basic button element" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button>Click Me</CoreComponents.button>
        """)

      assert html =~ "Click Me"
      assert html =~ "<button"
      assert html =~ "btn"
    end

    test "renders a link when navigate is provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button navigate="/home">Home</CoreComponents.button>
        """)

      assert html =~ "Home"
      assert html =~ ~s(href="/home")
      assert html =~ "btn"
    end

    test "renders a link when href is provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button href="https://example.com">External</CoreComponents.button>
        """)

      assert html =~ "External"
      assert html =~ ~s(href="https://example.com")
    end

    test "renders a link when patch is provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button patch="/edit">Edit</CoreComponents.button>
        """)

      assert html =~ "Edit"
      assert html =~ ~s(href="/edit")
    end

    test "applies primary variant class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button variant="primary">Primary</CoreComponents.button>
        """)

      assert html =~ "btn-primary"
    end

    test "applies default soft variant when no variant specified" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button>Default</CoreComponents.button>
        """)

      assert html =~ "btn-primary"
      assert html =~ "btn-soft"
    end

    test "passes extra attributes to button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button disabled>Disabled</CoreComponents.button>
        """)

      assert html =~ "disabled"
    end
  end

  describe "input/1 - text type" do
    test "renders a text input with label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="user[name]" label="Name" value="" id="name-input" />
        """)

      assert html =~ "Name"
      assert html =~ ~s(name="user[name]")
      assert html =~ ~s(type="text")
      assert html =~ ~s(id="name-input")
    end

    test "renders a text input without label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="user[name]" value="" id="no-label" />
        """)

      assert html =~ ~s(name="user[name]")
      refute html =~ "label mb-1"
    end

    test "renders error messages" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="user[name]" value="" id="err-input" errors={["is required"]} />
        """)

      assert html =~ "is required"
      assert html =~ "hero-exclamation-circle"
      assert html =~ "input-error"
    end

    test "applies custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="test" value="" id="cls-input" class="my-custom-class" />
        """)

      assert html =~ "my-custom-class"
    end

    test "applies custom error class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="test" value="" id="ecls-input" errors={["bad"]} error_class="my-error" />
        """)

      assert html =~ "my-error"
    end
  end

  describe "input/1 - hidden type" do
    test "renders a hidden input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="hidden" name="user[id]" value="42" id="hidden-input" />
        """)

      assert html =~ ~s(type="hidden")
      assert html =~ ~s(name="user[id]")
      assert html =~ ~s(value="42")
      # hidden inputs should not have label wrapper
      refute html =~ "fieldset"
    end
  end

  describe "input/1 - checkbox type" do
    test "renders a checkbox input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="checkbox" name="user[active]" label="Active" value="true" id="cb-input" />
        """)

      assert html =~ ~s(type="checkbox")
      assert html =~ "Active"
      assert html =~ ~s(name="user[active]")
      # Should have a hidden input for false value
      assert html =~ ~s(value="false")
    end

    test "renders a checked checkbox" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="checkbox" name="user[active]" value="true" checked={true} id="cb-checked" label="Active" />
        """)

      assert html =~ "checked"
    end

    test "renders checkbox with custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="checkbox" name="test" value="true" id="cb-cls" class="my-checkbox" label="Test" />
        """)

      assert html =~ "my-checkbox"
    end
  end

  describe "input/1 - select type" do
    test "renders a select input with options" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="select" name="user[role]" label="Role" value="" id="sel-input" options={[{"Admin", "admin"}, {"User", "user"}]} />
        """)

      assert html =~ "<select"
      assert html =~ "Role"
      assert html =~ ~s(value="admin")
      assert html =~ "Admin"
      assert html =~ ~s(value="user")
    end

    test "renders a select with prompt" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="select" name="user[role]" label="Role" value="" id="sel-prompt" options={["admin", "user"]} prompt="Choose..." />
        """)

      assert html =~ "Choose..."
    end

    test "renders a multiple select" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="select" name="user[roles]" label="Roles" value={[]} id="sel-multi" options={["admin", "editor"]} multiple={true} />
        """)

      assert html =~ "multiple"
    end

    test "renders select with error class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="select" name="test" value="" id="sel-err" options={["a"]} errors={["required"]} />
        """)

      assert html =~ "select-error"
    end

    test "renders select with custom error class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="select" name="test" value="" id="sel-cerr" options={["a"]} errors={["bad"]} error_class="my-sel-error" />
        """)

      assert html =~ "my-sel-error"
    end
  end

  describe "input/1 - textarea type" do
    test "renders a textarea" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="textarea" name="post[body]" label="Body" value="Hello" id="ta-input" />
        """)

      assert html =~ "<textarea"
      assert html =~ "Body"
      assert html =~ "Hello"
    end

    test "renders textarea with errors" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="textarea" name="post[body]" value="" id="ta-err" errors={["can't be blank"]} />
        """)

      assert html =~ "textarea-error"
      assert html =~ "can&#39;t be blank"
    end

    test "renders textarea with custom error class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="textarea" name="test" value="" id="ta-cerr" errors={["bad"]} error_class="my-ta-error" />
        """)

      assert html =~ "my-ta-error"
    end

    test "renders textarea with custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="textarea" name="test" value="" id="ta-cls" class="custom-ta" />
        """)

      assert html =~ "custom-ta"
    end
  end

  describe "input/1 - other types" do
    test "renders email input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="email" name="user[email]" label="Email" value="" id="email-input" />
        """)

      assert html =~ ~s(type="email")
      assert html =~ "Email"
    end

    test "renders password input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="password" name="user[password]" label="Password" value="" id="pw-input" />
        """)

      assert html =~ ~s(type="password")
    end

    test "renders number input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="number" name="qty" label="Quantity" value="5" id="num-input" />
        """)

      assert html =~ ~s(type="number")
      assert html =~ ~s(value="5")
    end

    test "renders date input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="date" name="event[date]" label="Date" value="2024-01-01" id="date-input" />
        """)

      assert html =~ ~s(type="date")
      assert html =~ ~s(value="2024-01-01")
    end

    test "renders with errors on generic input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="test" value="" id="gen-err" errors={["invalid"]} />
        """)

      assert html =~ "input-error"
      assert html =~ "invalid"
    end
  end

  describe "input/1 - with form field" do
    test "renders input from form field struct" do
      form = Phoenix.Component.to_form(%{"name" => "Alice"}, as: :user)

      assigns = %{form: form}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input field={@form[:name]} label="Name" />
        """)

      assert html =~ "Name"
      assert html =~ ~s(name="user[name]")
      assert html =~ ~s(value="Alice")
    end

    test "renders select from form field struct" do
      form = Phoenix.Component.to_form(%{"role" => "admin"}, as: :user)

      assigns = %{form: form}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input field={@form[:role]} type="select" label="Role" options={["admin", "user"]} />
        """)

      assert html =~ "<select"
      assert html =~ "admin"
    end
  end

  describe "header/1" do
    test "renders a header with title" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header>Page Title</CoreComponents.header>
        """)

      assert html =~ "Page Title"
      assert html =~ "<h1"
    end

    test "renders a header with subtitle" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header>
          Main Title
          <:subtitle>Some description</:subtitle>
        </CoreComponents.header>
        """)

      assert html =~ "Main Title"
      assert html =~ "Some description"
    end

    test "renders a header with actions" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header>
          Title
          <:actions>
            <CoreComponents.button>Action</CoreComponents.button>
          </:actions>
        </CoreComponents.header>
        """)

      assert html =~ "Action"
      assert html =~ "flex items-center justify-between"
    end
  end

  describe "table/1" do
    test "renders a table with columns and rows" do
      assigns = %{users: [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@users}>
          <:col :let={user} label="ID">{user.id}</:col>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ "Alice"
      assert html =~ "Bob"
      assert html =~ "ID"
      assert html =~ "Name"
      assert html =~ "table-zebra"
    end

    test "renders a table with action column" do
      assigns = %{users: [%{id: 1, name: "Alice"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@users}>
          <:col :let={user} label="Name">{user.name}</:col>
          <:action :let={user}>
            <.link navigate={"/users/#{user.id}"}>View</.link>
          </:action>
        </CoreComponents.table>
        """)

      assert html =~ "View"
      assert html =~ "Actions"
    end

    test "renders a table with custom row_id" do
      assigns = %{users: [%{id: 1, name: "Alice"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="user-table" rows={@users} row_id={fn user -> "user-#{user.id}" end}>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ ~s(id="user-1")
    end

    test "renders empty table with no rows" do
      assigns = %{users: []}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="empty-table" rows={@users}>
          <:col :let={user} label="Name">{user}</:col>
        </CoreComponents.table>
        """)

      assert html =~ "table-zebra"
      assert html =~ "Name"
    end
  end

  describe "list/1" do
    test "renders a data list" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.list>
          <:item title="Name">Alice</:item>
          <:item title="Role">Admin</:item>
        </CoreComponents.list>
        """)

      assert html =~ "Name"
      assert html =~ "Alice"
      assert html =~ "Role"
      assert html =~ "Admin"
      assert html =~ "list-row"
    end
  end

  describe "icon/1" do
    test "renders a hero icon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.icon name="hero-x-mark" />
        """)

      assert html =~ "hero-x-mark"
    end

    test "renders with custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.icon name="hero-arrow-path" class="size-8 animate-spin" />
        """)

      assert html =~ "hero-arrow-path"
      assert html =~ "size-8 animate-spin"
    end

    test "renders with default size-4 class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.icon name="hero-check" />
        """)

      assert html =~ "size-4"
    end
  end

  describe "show/1 and hide/1 JS commands" do
    test "show returns a JS struct" do
      js = CoreComponents.show("#my-element")
      assert %Phoenix.LiveView.JS{} = js
    end

    test "hide returns a JS struct" do
      js = CoreComponents.hide("#my-element")
      assert %Phoenix.LiveView.JS{} = js
    end

    test "show with existing JS struct chains commands" do
      js = Phoenix.LiveView.JS.push("some-event") |> CoreComponents.show("#target")
      assert %Phoenix.LiveView.JS{} = js
    end

    test "hide with existing JS struct chains commands" do
      js = Phoenix.LiveView.JS.push("some-event") |> CoreComponents.hide("#target")
      assert %Phoenix.LiveView.JS{} = js
    end
  end

  describe "translate_error/1" do
    test "translates a simple error message" do
      assert CoreComponents.translate_error({"is invalid", []}) == "is invalid"
    end

    test "translates error with count option" do
      result = CoreComponents.translate_error({"should be at least %{count} character(s)", [count: 3]})
      assert result =~ "3"
    end
  end

  describe "translate_errors/2" do
    test "translates errors for a specific field" do
      errors = [name: {"can't be blank", []}, email: {"is invalid", []}]

      result = CoreComponents.translate_errors(errors, :name)
      assert result == ["can't be blank"]
    end

    test "returns empty list when field has no errors" do
      errors = [name: {"can't be blank", []}]

      result = CoreComponents.translate_errors(errors, :email)
      assert result == []
    end

    test "returns multiple errors for same field" do
      errors = [name: {"can't be blank", []}, name: {"is too short", []}]

      result = CoreComponents.translate_errors(errors, :name)
      assert length(result) == 2
    end
  end
end
