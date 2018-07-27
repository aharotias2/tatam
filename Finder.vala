using Gtk, DPlayer;

namespace DPlayer {

    Gdk.Pixbuf parent_pixbuf;
    Gdk.Pixbuf folder_pixbuf;
    Gdk.Pixbuf file_pixbuf;
    Gdk.Pixbuf cd_pixbuf;
    
    delegate void FinderItemBookmarkButtonClickedFunc(string file_path);
    delegate void FinderItemAddButtonClickedFunc(string file_path);
    delegate void FinderItemPlayButtonClickedFunc(string file_path);

    public class ImageLoaderThreadData {
        private string file_path;
        private int icon_size;
        public Gdk.Pixbuf? icon_pixbuf { get; set; }
        public bool pixbuf_loaded;
        public ImageLoaderThreadData(string file_path, int icon_size) {
            this.file_path = file_path;
            this.icon_size = icon_size;
            this.icon_pixbuf = null;
            this.pixbuf_loaded = false;
        }
        public void* run() {
            debug("thread starts");
            try {
                icon_pixbuf = new DFileUtils(file_path).load_first_artwork(icon_size);
            } catch (FileError e) {
                Process.exit(1);
            }
            debug("thread ends %s of %s", (icon_pixbuf != null ? "icon has been loaded" : "icon is null"), file_path);
            pixbuf_loaded = true;
            return icon_pixbuf;
        }
    }

    private class FinderItem : FlowBoxChild {
        /* Properties */
        public string file_path { get; private set; }
        public string file_name { get; private set; }
        public DFileType file_type { get; private set; }
        public string dir_path { get; private set; }
        public int icon_size { get; set; }

        public Button icon_button { get; private set; }
        public Button add_button { get; private set; }
        public Button bookmark_button { get; private set; }
        public Button play_button { get; private set; }
        public Image icon_image { get; set; }
        
        private Thread<void *>? thread;
        private ImageLoaderThreadData? thdata;
        
        public FinderItemBookmarkButtonClickedFunc bookmark_button_clicked_func {
            set {
                bookmark_button.clicked.connect(() => {
                        value(file_path);
                    });
            }
        }
        public FinderItemAddButtonClickedFunc add_button_clicked_func {
            set {
                add_button.clicked.connect(() => {
                        value(file_path);
                    });
            }
        }
        public FinderItemPlayButtonClickedFunc play_button_clicked_func {
            set {
                play_button.clicked.connect(() => {
                        value(file_path);
                    });
            }
        }

        /* Contructor */
        public FinderItem(ref DFileInfo file_info, int icon_size = 128, bool use_popover = true) {
            this.file_path = file_info.path;
            this.file_name = file_info.name;
            this.dir_path = file_info.dir;
            this.file_type = file_info.file_type;
            this.thread = null;
            this.thdata = null;
            this.icon_size = icon_size;
            
            var ev_box = new EventBox();
            {
                var widget_overlay2 = new Overlay();
                {           
                    icon_button = new Button();
                    {
                        var widget_overlay1 = new Overlay();
                        {
                            Gdk.Pixbuf? icon_pixbuf = null;
                            {
                                this.file_path = Path.build_path(Path.DIR_SEPARATOR_S, dir_path, file_name);
                                debug("file_path: " + file_path);

                                switch (file_type) {
                                case DFileType.DISC:
                                    debug("file_type: disc");
                                    bool thread_started = false;
                                    thdata = new ImageLoaderThreadData(this.file_path, this.icon_size);
                                    Timeout.add(80, () => {
                                            if (!thread_started) {
                                                thread = new Thread<void*>.try(this.file_path, thdata.run);
                                                thread_started = true;
                                            } else if (thdata.pixbuf_loaded) {
                                                debug("tmp_icon_pixbuf has been loaded");
                                                thread.join();
                                                if (thdata.icon_pixbuf != null) {
                                                    icon_image.set_from_pixbuf(thdata.icon_pixbuf);
                                                }
                                                return Source.REMOVE;
                                            }
                                            return Source.CONTINUE;
                                        }, Priority.DEFAULT);
                                    if (icon_pixbuf == null) {
                                        icon_pixbuf = cd_pixbuf;
                                    }
                                    break;

                                case DFileType.DIRECTORY:
                                    debug("file_type: directory");
                                    icon_pixbuf = folder_pixbuf;
                                    break;

                                case DFileType.PARENT:
                                    debug("file_type: parent");
                                    icon_pixbuf = parent_pixbuf.scale_simple(icon_size, icon_size, Gdk.InterpType.BILINEAR);
                                    break;

                                case DFileType.FILE:
                                default:
                                    debug("file_type: file");
                                    if (file_info.artwork != null) {
                                        icon_pixbuf = file_info.artwork.scale_simple(icon_size, icon_size, Gdk.InterpType.BILINEAR);
                                    } else {
                                        icon_pixbuf = file_pixbuf;
                                    }
                                    break;

                                }
                            }

                            icon_image = new Image.from_pixbuf(icon_pixbuf);
                            
                            var item_label = new Label(file_name);
                            {
                                item_label.ellipsize = Pango.EllipsizeMode.END;
                                item_label.lines = 5;
                                item_label.single_line_mode = false;
                                item_label.max_width_chars = 20;
                                item_label.margin = 0;
                                item_label.wrap = true;
                                item_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
                                item_label.valign = Align.END;
                                Gdk.RGBA item_label_bg_color = {0.1, 0.1, 0.1, 0.5};
                                item_label.override_background_color(Gtk.StateFlags.NORMAL, item_label_bg_color);
                                Gdk.RGBA item_label_color = {1.0, 1.0, 1.0, 1.0};
                                item_label.override_color(Gtk.StateFlags.NORMAL, item_label_color);
                            }

                            Button? mini_icon_button = null;
                            {
                                Image mini_icon = null;
                                {
                                    if (file_type == DFileType.FILE && icon_pixbuf != file_pixbuf) {
                                        mini_icon = new Image.from_icon_name("audio-x-generic-symbolic", IconSize.LARGE_TOOLBAR);
                                    } else if (file_type == DFileType.DISC && icon_pixbuf != cd_pixbuf) {
                                        mini_icon = new Image.from_icon_name("folder-symbolic", IconSize.LARGE_TOOLBAR);
                                    }
                                
                                    if (mini_icon != null) {
                                        mini_icon.halign = Align.START;
                                        mini_icon.valign = Align.START;
                                    }
                                }

                                if (mini_icon != null) {
                                    mini_icon_button = new Button();
                                    mini_icon_button.halign = Align.START;
                                    mini_icon_button.valign = Align.START;
                                    Gdk.RGBA mini_icon_bgcolor = {0.5, 0.5, 0.5, 0.5};
                                    mini_icon_button.override_background_color(Gtk.StateFlags.NORMAL, mini_icon_bgcolor);
                                    mini_icon_button.add(mini_icon);
                                }
                            }
                            
                            widget_overlay1.add(icon_image);
                            widget_overlay1.add_overlay(item_label);
                            widget_overlay1.set_overlay_pass_through(item_label, true);

                            if (mini_icon_button != null) {
                                widget_overlay1.add_overlay(mini_icon_button);
                                widget_overlay1.set_overlay_pass_through(mini_icon_button, true);
                            }
                        }

                        icon_button.hexpand = false;
                        icon_button.vexpand = false;
                        icon_button.border_width = 0;
                        icon_button.get_style_context().add_class("flat");
                        icon_button.add(widget_overlay1);
                    }

                    var button_box = new Box(Orientation.HORIZONTAL, 5);
                    {
                        bookmark_button = new Button.from_icon_name("user-bookmarks-symbolic", IconSize.SMALL_TOOLBAR);
                        {
                            bookmark_button.valign = Align.CENTER;
                            bookmark_button.visible = false;
                            bookmark_button.get_style_context().add_class("finder-button");
                        }

                        add_button = new Button.from_icon_name("list-add-symbolic", IconSize.SMALL_TOOLBAR);
                        {
                            add_button.valign = Align.CENTER;
                            add_button.visible = false;
                            add_button.get_style_context().add_class("finder-button");
                        }

                        play_button = new Button.from_icon_name("media-playback-start-symbolic", IconSize.LARGE_TOOLBAR);
                        {
                            play_button.valign = Align.CENTER;
                            play_button.visible = false;
                            play_button.get_style_context().add_class("finder-button");
                        }

                        button_box.halign = Align.CENTER;
                        button_box.valign = Align.CENTER;
                        if (file_type != DFileType.PARENT) {
                            if (use_popover) {
                                if (file_type == DFileType.DIRECTORY || file_type == DFileType.DISC) {
                                    button_box.pack_start(add_popover_to_button(bookmark_button, "Add to bookmark list"), false, false);
                                }
                                button_box.pack_start(add_popover_to_button(play_button, "Play it"), false, false);
                                button_box.pack_start(add_popover_to_button(add_button, "Add to playlist"), false, false);
                            } else {
                                if (file_type == DFileType.DIRECTORY || file_type == DFileType.DISC) {
                                    button_box.pack_start(bookmark_button, false, false);
                                }
                                button_box.pack_start(play_button, false, false);
                                button_box.pack_start(add_button, false, false);
                            }
                        }
                    }

                    widget_overlay2.add(icon_button);
                    widget_overlay2.add_overlay(button_box);
                }
            
                ev_box.enter_notify_event.connect((event) => {
                        show_buttons();
                        return Source.CONTINUE;
                    });
                ev_box.leave_notify_event.connect((event) => {
                        hide_buttons();
                        return Source.CONTINUE;
                    });

                ev_box.add(widget_overlay2);
            }
            
            vexpand = false;
            hexpand = false;
            add(ev_box);
        }

        /* Public methods */
        public void hide_buttons() {
            add_button.visible = bookmark_button.visible = play_button.visible = false;
        }

        public void show_buttons() {
            add_button.visible = bookmark_button.visible = play_button.visible = true;
        }

        /* Private methods */
        private EventBox add_popover_to_button(Button button, string pop_text) {
            var pop = new Popover(button);
            pop.add(new Label(pop_text));
            pop.set_default_widget(this);
            pop.modal = false;
            pop.transitions_enabled = false;
            pop.position = PositionType.BOTTOM;
            pop.show_all();

            var ev_box = new EventBox();
            ev_box.add(button);
            ev_box.enter_notify_event.connect((event) => {
                    pop.visible = true;
                    return Source.CONTINUE;
                });
            
            ev_box.leave_notify_event.connect((event) => {
                    pop.visible = false;
                    return Source.CONTINUE;
                });

            return (owned) ev_box;
        }
    }

    class Finder : Bin {
        private int count;
        private IconTheme icon_theme;

        /* Private fields */
        private ScrolledWindow finder_container;
        private FlowBox finder;
        private ProgressBar progress;
        private Revealer progress_revealer;
        private Label while_label;
        
        private List<DFileInfo?> file_info_list;

        private CompareFunc<string> string_compare_func;

        /* Properties */
        public int icon_size { get; set; }
        public bool use_popover { get; set; }
        public string dir_path { get; set; }
        public bool activate_on_single_click { get; set; }

        public FinderItemBookmarkButtonClickedFunc bookmark_button_clicked_func { get; set; }
        public FinderItemAddButtonClickedFunc add_button_clicked_func { get; set; }
        public FinderItemPlayButtonClickedFunc play_button_clicked_func { get; set; }

        /* Constructor */
        public Finder() {
            string_compare_func = (a, b) => {
                return a.collate(b);
            };

            count = 0;
            debug("creating finder start");
            activate_on_single_click = true;
            icon_theme = Gtk.IconTheme.get_default();
            icon_size = 128;

            try {
                file_pixbuf = icon_theme.load_icon("audio-x-generic", icon_size, 0);
                cd_pixbuf = icon_theme.load_icon("media-optical", icon_size, 0);
                folder_pixbuf = icon_theme.load_icon("folder-music", icon_size, 0);
                if (folder_pixbuf == null) {
                    folder_pixbuf = icon_theme.load_icon("folder", icon_size, 0);
                }
                parent_pixbuf = icon_theme.load_icon("go-up", icon_size, 0);
            } catch (Error e) {
                stderr.printf("icon file can not load.\n");
                Process.exit(1);
            }

            var overlay_while_label = new Overlay();
            {
                var finder_box = new Box(Orientation.VERTICAL, 1);
                {
                    finder_container = new ScrolledWindow(null, null);
                    {
                        finder_container.get_style_context().add_class("view");
                    }
                
                    progress_revealer = new Revealer();
                    {
                        progress = new ProgressBar();
                        {
                            progress.show_text = false;
                        }
                
                        progress_revealer.reveal_child = false;
                        progress_revealer.transition_type = RevealerTransitionType.SLIDE_DOWN;
                        progress_revealer.valign = Align.START;
                        progress_revealer.add(progress);
                    }
            
                    finder_box.pack_start(progress_revealer, false, false);
                    finder_box.pack_start(finder_container, true, true);
                }
            
                var while_label_box = new Box(Orientation.VERTICAL, 4);
                {
                    while_label = new Label("");
                    {
                        while_label.margin = 4;
                    }

                    Gdk.RGBA while_label_bg_color = {0.1, 0.1, 0.1, 0.5};
                    Gdk.RGBA while_label_fg_color = {0.9, 0.9, 0.9, 1.0};

                    while_label_box.override_background_color(Gtk.StateFlags.NORMAL, while_label_bg_color);
                    while_label_box.override_color(Gtk.StateFlags.NORMAL, while_label_fg_color);
                    while_label_box.pack_start(while_label);
                    while_label_box.hexpand = false;
                    while_label_box.vexpand = false;
                    while_label_box.halign = Align.CENTER;
                    while_label_box.valign = Align.CENTER;
                }
            
                overlay_while_label.add(finder_box);
                overlay_while_label.add_overlay(while_label_box);
            }

            add(overlay_while_label);

            debug("creating finder end");
        }

        /* Public methods */

        public void change_dir(string dir_path) {
            debug("start change_dir (" + dir_path + ")");
            this.dir_path = dir_path;
            change_cursor(Gdk.CursorType.WATCH);

            while_label.visible = true;
            while_label.label = "Loading data from disk...";

            Timeout.add(10, () => {
                    //debug("start timeout routine (change_dir) level 1");

                    file_info_list = new DFileUtils(dir_path).get_file_info_and_artwork_list_in_dir();

                    if (finder != null) {
                        finder_container.remove(finder.get_parent());
                        finder = null;
                    }

                    finder = new FlowBox();
                    finder.max_children_per_line = 100;
                    finder.min_children_per_line = 1;
                    finder.row_spacing = 0;
                    finder.column_spacing = 0;
                    finder.homogeneous = true;
                    finder.selection_mode = SelectionMode.NONE;
                    finder.halign = Align.START;
                    finder.valign = Align.START;
                    uint i = 0;
                    finder_container.add(finder);


                    Timeout.add(40, () => {
                            //debug("start timeout routine (change_dir) level 2: %u times", i);
                            if (i < this.file_info_list.length()) {
                                DFileInfo file_info = this.file_info_list.nth_data(i);
                                //debug("item is " + file_info.path + " (name:" + file_info.name + ")");
                                if (file_info.name != "..") {
                                    while_label.label = file_info.name + " is loaded.";
                                }
                                if (file_info.file_type == DFileType.DIRECTORY) {
                                    try {
                                        file_info.file_type = new DFileUtils(file_info.path).determine_file_type();
                                    } catch (FileError e) {
                                        stderr.printf("FileError catched with file_info.path '" + file_info.path + "' which is cannot open");
                                        return Source.REMOVE;
                                    }
                                }

                                var item_widget = new FinderItem(ref file_info, icon_size, use_popover);
                                if (item_widget == null) {
                                    //debug("item is null (" + file_info.path + ")");
                                } else {
                                    switch (file_info.file_type) {
                                      case DFileType.DIRECTORY:
                                      case DFileType.DISC:
                                        item_widget.icon_button.clicked.connect(() => {
                                                change_dir(file_info.path);
                                            });
                                        item_widget.bookmark_button_clicked_func = this.bookmark_button_clicked_func;
                                        break;
                                      case DFileType.PARENT:
                                        item_widget.icon_button.clicked.connect(() => {
                                                change_dir(file_info.path);
                                            });
                                        break;
                                      case DFileType.FILE:
                                        item_widget.icon_button.clicked.connect(() => {
                                                play_button_clicked_func(file_info.path);
                                            });
                                        break;
                                    }
                                }
                                item_widget.add_button_clicked_func = this.add_button_clicked_func;
                                item_widget.play_button_clicked_func = this.play_button_clicked_func;

                                finder.add(item_widget);

                                i++;
                                double fraction = (double) i / (double) file_info_list.length();
                                progress.fraction = fraction;
                                //string percentage = "%0.0f%%".printf(fraction * 100);

                                //debug("fraction: " + percentage);
                                //debug("end timeout routine (change_dir) level 2: %u times",i);

                                finder_container.show_all();
                                for (int j = 0; j < file_info_list.length(); j++) {
                                    ((FinderItem)finder.get_child_at_index(j)).hide_buttons();
                                    while_label.visible = false;
                                }
                                return Source.CONTINUE;
                            } else {
                                debug("end change dir (" + dir_path + ")");

                                change_cursor(Gdk.CursorType.LEFT_PTR);
                                progress_revealer.reveal_child = false;
                                debug("end timeout routine (change_dir) level 2: %u times",i);
                                return Source.REMOVE;
                            }
                        }, Priority.HIGH_IDLE);

                    progress.set_fraction(0.0);
                    progress_revealer.reveal_child = true;
                    debug("end timeout routine (change_dir) level 1");
                    return Source.REMOVE;
                }, Priority.HIGH);
        }

        /*
        public void set_picture_size(int new_icon_size) {
            try {
                icon_size = new_icon_size;
                file_pixbuf = icon_theme.load_icon("audio-x-generic", icon_size, 0);
                cd_pixbuf = icon_theme.load_icon("media-optical", icon_size, 0);
                folder_pixbuf = icon_theme.load_icon("folder-music", icon_size, 0);
                if (folder_pixbuf == null) {
                    folder_pixbuf = icon_theme.load_icon("folder", icon_size, 0);
                }
                parent_pixbuf = icon_theme.load_icon("go-up", icon_size, 0);
                change_dir(dir_path);
            } catch (Error e) {
                stderr.printf("icon file can not load.\n");
                Process.exit(1);
            }
        }
        */

        public void change_cursor(Gdk.CursorType cursor_type) {
            finder_container.get_parent_window().set_cursor(new Gdk.Cursor.for_display(Gdk.Screen.get_default().get_display(), cursor_type));
        }

        public void hide_while_label() {
            while_label.visible = false;
        }
    }
}
