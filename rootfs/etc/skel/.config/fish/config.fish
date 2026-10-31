# RAVLIN Graphical fish configuration
# Copied into every new user's home from /etc/skel by useradd -m.
# fish ships smart tab-completion and autosuggestions out of the box.

if status is-interactive
    set -g fish_greeting "RAVLIN Graphical — minimal Void Linux remix with KDE Plasma"

    # black & silver theme with green / pink / orange text
    set -g fish_color_normal c0c0c0
    set -g fish_color_command a6f28a
    set -g fish_color_param ffb454
    set -g fish_color_option ffb454
    set -g fish_color_operator ffb454
    set -g fish_color_error fb7185
    set -g fish_color_valid_path c0c0c0 --underline
    set -g fish_color_comment 7f7f8c
    set -g fish_color_autosuggestion 5c5c66
    set -g fish_color_cwd a6f28a
    set -g fish_color_host c0c0c0
    set -g fish_color_user a6f28a
    set -g fish_color_search_match --background=1c1c22

    function fish_prompt
        # root gets a red user tag, everyone else magenta
        set -l user_color --bold magenta
        if test (id -u) -eq 0
            set user_color --bold red
        end

        set -l user (set_color $user_color)$USER(set_color normal)
        set -l host (set_color --bold cyan)(prompt_hostname)(set_color normal)
        set -l cwd (set_color --bold green)(prompt_pwd)(set_color normal)

        echo -n "$user@$host $cwd > "
    end
end
