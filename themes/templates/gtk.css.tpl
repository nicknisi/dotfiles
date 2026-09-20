/* {{ name }} — rendered by bin/theme from themes/templates/gtk.css.tpl.
   ~/.config/gtk-3.0/gtk.css and ~/.config/gtk-4.0/gtk.css @import this file
   (bin/theme writes that one line, once). Colours only: widget shapes stay
   stock Adwaita, so a pack recolours Nautilus, the file chooser and Seahorse
   without a GTK theme of its own. Apps read gtk.css when they start.

   libadwaita names, both spellings: the @define-color set every version
   understands, and the CSS variables 1.6+ prefer. Surfaces move a few percent
   toward the foreground for "raised", which is lighter on a dark pack and
   darker on a light one, the way Adwaita's own dark and light sheets go. */

@define-color accent_bg_color {{ accent }};
@define-color accent_fg_color {{ background }};
@define-color accent_color {{ accent }};
@define-color destructive_bg_color {{ red }};
@define-color destructive_fg_color {{ background }};
@define-color destructive_color {{ red }};
@define-color success_bg_color {{ green }};
@define-color success_fg_color {{ background }};
@define-color success_color {{ green }};
@define-color warning_bg_color {{ yellow }};
@define-color warning_fg_color {{ background }};
@define-color warning_color {{ yellow }};
@define-color error_bg_color {{ red }};
@define-color error_fg_color {{ background }};
@define-color error_color {{ red }};

@define-color window_bg_color {{ background }};
@define-color window_fg_color {{ foreground }};
@define-color view_bg_color {{ dark_background }};
@define-color view_fg_color {{ foreground }};
@define-color headerbar_bg_color {{ mix background foreground 6% }};
@define-color headerbar_fg_color {{ foreground }};
@define-color headerbar_border_color alpha({{ muted }}, 0.5);
@define-color headerbar_backdrop_color {{ background }};
@define-color headerbar_shade_color alpha({{ darker_background }}, 0.6);
@define-color headerbar_darker_shade_color alpha({{ darker_background }}, 0.8);
@define-color sidebar_bg_color {{ mix background foreground 4% }};
@define-color sidebar_fg_color {{ foreground }};
@define-color sidebar_backdrop_color {{ mix background foreground 2% }};
@define-color sidebar_border_color alpha({{ muted }}, 0.5);
@define-color sidebar_shade_color alpha({{ darker_background }}, 0.6);
@define-color secondary_sidebar_bg_color {{ mix background foreground 2% }};
@define-color secondary_sidebar_fg_color {{ foreground }};
@define-color secondary_sidebar_backdrop_color {{ background }};
@define-color secondary_sidebar_border_color alpha({{ muted }}, 0.5);
@define-color secondary_sidebar_shade_color alpha({{ darker_background }}, 0.6);
@define-color card_bg_color {{ mix background foreground 5% }};
@define-color card_fg_color {{ foreground }};
@define-color card_shade_color alpha({{ darker_background }}, 0.6);
@define-color dialog_bg_color {{ mix background foreground 8% }};
@define-color dialog_fg_color {{ foreground }};
@define-color popover_bg_color {{ mix background foreground 8% }};
@define-color popover_fg_color {{ foreground }};
@define-color popover_shade_color alpha({{ darker_background }}, 0.6);
@define-color thumbnail_bg_color {{ lighter_background }};
@define-color thumbnail_fg_color {{ foreground }};
@define-color shade_color alpha({{ darker_background }}, 0.6);
@define-color scrollbar_outline_color alpha({{ background }}, 0.5);

:root {
  --accent-bg-color: {{ accent }};
  --accent-fg-color: {{ background }};
  --accent-color: {{ accent }};
  --destructive-bg-color: {{ red }};
  --destructive-fg-color: {{ background }};
  --destructive-color: {{ red }};
  --success-bg-color: {{ green }};
  --success-fg-color: {{ background }};
  --success-color: {{ green }};
  --warning-bg-color: {{ yellow }};
  --warning-fg-color: {{ background }};
  --warning-color: {{ yellow }};
  --error-bg-color: {{ red }};
  --error-fg-color: {{ background }};
  --error-color: {{ red }};
  --window-bg-color: {{ background }};
  --window-fg-color: {{ foreground }};
  --view-bg-color: {{ dark_background }};
  --view-fg-color: {{ foreground }};
  --headerbar-bg-color: {{ mix background foreground 6% }};
  --headerbar-fg-color: {{ foreground }};
  --headerbar-border-color: alpha({{ muted }}, 0.5);
  --headerbar-backdrop-color: {{ background }};
  --headerbar-shade-color: alpha({{ darker_background }}, 0.6);
  --headerbar-darker-shade-color: alpha({{ darker_background }}, 0.8);
  --sidebar-bg-color: {{ mix background foreground 4% }};
  --sidebar-fg-color: {{ foreground }};
  --sidebar-backdrop-color: {{ mix background foreground 2% }};
  --sidebar-border-color: alpha({{ muted }}, 0.5);
  --sidebar-shade-color: alpha({{ darker_background }}, 0.6);
  --secondary-sidebar-bg-color: {{ mix background foreground 2% }};
  --secondary-sidebar-fg-color: {{ foreground }};
  --secondary-sidebar-backdrop-color: {{ background }};
  --secondary-sidebar-border-color: alpha({{ muted }}, 0.5);
  --secondary-sidebar-shade-color: alpha({{ darker_background }}, 0.6);
  --card-bg-color: {{ mix background foreground 5% }};
  --card-fg-color: {{ foreground }};
  --card-shade-color: alpha({{ darker_background }}, 0.6);
  --dialog-bg-color: {{ mix background foreground 8% }};
  --dialog-fg-color: {{ foreground }};
  --popover-bg-color: {{ mix background foreground 8% }};
  --popover-fg-color: {{ foreground }};
  --popover-shade-color: alpha({{ darker_background }}, 0.6);
  --thumbnail-bg-color: {{ lighter_background }};
  --thumbnail-fg-color: {{ foreground }};
  --shade-color: alpha({{ darker_background }}, 0.6);
  --scrollbar-outline-color: alpha({{ background }}, 0.5);
}

/* GTK3 Adwaita exports these; its own widget rules are compiled with literal
   colours, so this reaches apps that reference the names, not every widget. */
@define-color theme_bg_color {{ background }};
@define-color theme_fg_color {{ foreground }};
@define-color theme_base_color {{ dark_background }};
@define-color theme_text_color {{ foreground }};
@define-color theme_selected_bg_color {{ accent }};
@define-color theme_selected_fg_color {{ background }};
@define-color theme_unfocused_bg_color {{ background }};
@define-color theme_unfocused_fg_color {{ dark_foreground }};
@define-color theme_unfocused_base_color {{ dark_background }};
@define-color theme_unfocused_text_color {{ dark_foreground }};
@define-color theme_unfocused_selected_bg_color {{ muted }};
@define-color theme_unfocused_selected_fg_color {{ foreground }};
@define-color insensitive_bg_color {{ mix background foreground 3% }};
@define-color insensitive_fg_color {{ dark_foreground }};
@define-color insensitive_base_color {{ background }};
@define-color borders alpha({{ muted }}, 0.6);
@define-color unfocused_borders alpha({{ muted }}, 0.4);
@define-color warning_color {{ yellow }};
@define-color error_color {{ red }};
@define-color success_color {{ green }};
