/*
 * This file is part of mpd.
 * 
 *     mpd is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 * 
 *     mpd is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 * 
 *     You should have received a copy of the GNU General Public License
 *     along with mpd.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright 2018 Takayuki Tanaka
 */

using Gtk, Mpd;

//--------------------------------------------------------------------------------------
// Delegates
//--------------------------------------------------------------------------------------
delegate void TimeLabelSetFunc(double seconds);

//--------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// global variables for file management
//--------------------------------------------------------------------------------------
List<string> dirs;
CompareFunc<string> string_compare_func;
CopyFunc<DFileInfo?> file_info_copy_func;
string current_dir = null;

//--------------------------------------------------------------------------------------
// global variable for playing music
//--------------------------------------------------------------------------------------
Music music;

string music_total_time;
double music_total_time_seconds;
double music_time_position;
Gdk.Pixbuf current_playing_artwork;

//--------------------------------------------------------------------------------------
// global variables for images
//--------------------------------------------------------------------------------------
Gdk.Pixbuf cd_pixbuf;
Gdk.Pixbuf folder_pixbuf;
Gdk.Pixbuf file_pixbuf;
Gdk.Pixbuf parent_pixbuf;
int max_width;
int max_height;
int artwork_max_size;

//--------------------------------------------------------------------------------------
// global variables for widgets
//--------------------------------------------------------------------------------------
Window main_win;
HeaderBar? win_header;
MpdStack stack;
Button artwork_button;
Image artwork;
Box controller;
Overlay music_view_overlay;
Button header_switch_button;
Button header_add_button;
Button finder_add_button;
Button finder_parent_button;
Button finder_zoomin_button;
Button finder_zoomout_button;
Button finder_refresh_button;
Entry finder_location;
Image music_view_artwork;
Label music_title;
Scale time_bar;
Label time_label_current;
Label time_label_rest;
ToolButton play_pause_button;
ToolButton next_track_button;
ToolButton prev_track_button;
ToggleButton toggle_shuffle_button;
ToggleButton toggle_repeat_button;
Mpd.Finder finder;
TreeView bookmark_tree;
TreeIter bookmark_root;
TreeIter playlist_root;
Mpd.PlaylistBox playlist;
ScrolledWindow music_view_container;
Label playlist_view_dir_label;
TimeLabelSetFunc time_label_set;
int saved_main_win_width;
int saved_main_win_height;
int window_default_width = 900;
int window_default_height = 750;

Dialog? help_dialog = null;
Dialog? config_dialog = null;
Dialog? save_playlist_dialog = null;

const Gdk.RGBA music_view_bg_color = {0.1, 0.1, 0.1, 1.0};
const Gdk.RGBA music_view_close_button_bg_color = {0.8, 0.8, 0.8, 0.4};

const string[] icon_dirs = {"/usr/share/icons/hicolor/48x48/apps/",
                            "/usr/local/share/icons/hicolor/48x48/apps/",
                            "~/.icons"};

//--------------------------------------------------------------------------------------
// other global variables
//--------------------------------------------------------------------------------------
bool print_message_of_send_mplayer_command;
MpdOptions options;

//--------------------------------------------------------------------------------------
// utility functions
//--------------------------------------------------------------------------------------
Gdk.Pixbuf? get_application_icon_at_size(uint width, uint height) {
    try {
        foreach (string dir in icon_dirs) {
            if (dir.index_of_char('~') == 0) {
                dir = dir.replace("~", Environment.get_home_dir());
            }
            string icon_name = dir + "/" + PROGRAM_NAME + ".png";
            debug("icon path : " + icon_name);
            if (FileUtils.test(icon_name, FileTest.EXISTS)) {
                return new Gdk.Pixbuf.from_file_at_size(icon_name, 64, 64);
            }
        }
        return null;
    } catch (Error e) {
        return null;
    }
}

//--------------------------------------------------------------------------------------
// application functions
//--------------------------------------------------------------------------------------

void application_quit() {
    if (music.playing) {
        music.quit();
    }

    Idle.add(() => {
            if (!music.playing) {
                Gtk.main_quit();
                if (playlist.name != null) {
                    options.last_playlist_name = playlist.name;
                }
                return Source.REMOVE;
            } else {
                return Source.CONTINUE;
            }
        });
}

bool confirm(string message) {
    Gtk.MessageDialog m = new Gtk.MessageDialog(main_win, DialogFlags.MODAL, MessageType.WARNING, ButtonsType.OK_CANCEL, message);
    Gtk.ResponseType result = (ResponseType)m.run ();
    m.close ();
    return result == Gtk.ResponseType.OK;
}

void show_about_dialog(Window main_win) {
    if (help_dialog == null) {
        help_dialog = new Dialog.with_buttons(PROGRAM_NAME + " info",
                                              main_win,
                                              DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
                                              "_OK",
                                              ResponseType.NONE);
        {
            var help_dialog_vbox = new Box(Orientation.VERTICAL, 0);
            {
                var help_dialog_label_text = new Label("<span size=\"24000\"><b>" + PROGRAM_NAME + "</b></span>");
                help_dialog_label_text.use_markup = true;
                help_dialog_label_text.margin = 10;

                help_dialog_vbox.pack_start(new Image.from_pixbuf(get_application_icon_at_size(64, 64)));
                help_dialog_vbox.pack_start(help_dialog_label_text, false, false);
                help_dialog_vbox.pack_start(new Label(Text.DESCRIPTION), false, false);
                help_dialog_vbox.pack_start(new Label(Text.COPYRIGHT), false, false);
                help_dialog_vbox.margin = 20;
            }
            help_dialog.get_content_area().add(help_dialog_vbox);
            help_dialog.response.connect(() => {
                    help_dialog.visible = false;
                });
            help_dialog.destroy.connect(() => {
                    help_dialog = null;
                });
            help_dialog.show_all();
        }
    }
    help_dialog.visible = true;
}

void show_config_dialog(Window main_win) {
    if (config_dialog == null) {
        string _ao_type = options.ao_type;
        bool _use_csd = options.use_csd;
        RadioButton radio_audio_alsa;
        RadioButton radio_audio_pulse;
        RadioButton radio_use_csd_yes;
        RadioButton radio_use_csd_no;
        SpinButton spin_thumbnail_size;
        SpinButton spin_playlist_image_size;

        config_dialog = new Dialog.with_buttons(PROGRAM_NAME + Text.SETTINGS,
                                                main_win,
                                                DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
                                                Text.DIALOG_OK,
                                                ResponseType.ACCEPT,
                                                Text.DIALOG_CANCEL,
                                                ResponseType.CANCEL);
        {
            var config_dialog_vbox = new Box(Orientation.VERTICAL, 5);
            {
                // Select ALSA or PulseAudio
                var frame_audio_choice = new Frame(Text.CONFIG_DIALOG_HEADER_AUDIO);
                {
                    var frame_audio_choice_vbox = new Box(Orientation.VERTICAL, 0);
                    {
                        radio_audio_alsa = new RadioButton.with_label(null, "ALSA");
                        {
                            if (options.ao_type == "alsa") {
                                radio_audio_alsa.active = true;
                            }
                            radio_audio_alsa.toggled.connect(() => {
                                    _ao_type = radio_audio_alsa.active ? "alsa" : "pulse";
                                });
                        }

                        radio_audio_pulse = new RadioButton.with_label_from_widget(radio_audio_alsa, "PulseAudio");
                        {
                            if (options.ao_type == "pulse") {
                                radio_audio_pulse.active = true;
                            }
                            radio_audio_pulse.toggled.connect(() => {
                                    _ao_type = radio_audio_pulse.active ? "pulse" : "alsa";
                                });
                        }

                        frame_audio_choice_vbox.margin = 5;
                        frame_audio_choice_vbox.pack_start(radio_audio_alsa);
                        frame_audio_choice_vbox.pack_start(radio_audio_pulse);
                    }

                    frame_audio_choice.add(frame_audio_choice_vbox);
                }

                var frame_thumbnail_size = new Frame(Text.CONFIG_DIALOG_HEADER_THUMBS);
                {
                    spin_thumbnail_size = new SpinButton.with_range(1, 500, 1);
                    {
                        spin_thumbnail_size.margin = 5;
                        spin_thumbnail_size.numeric = false;
                        spin_thumbnail_size.value = options.thumbnail_size;
                    }

                    frame_thumbnail_size.add(spin_thumbnail_size);
                }

                var frame_playlist_image_size = new Frame(Text.CONFIG_DIALOG_HEADER_PLAYLIST_IMAGE);
                {
                    spin_playlist_image_size = new SpinButton.with_range(16, 256, 1);
                    {
                        spin_playlist_image_size.margin = 5;
                        spin_playlist_image_size.numeric = false;
                        spin_playlist_image_size.value = options.playlist_image_size;
                    }

                    frame_playlist_image_size.add(spin_playlist_image_size);
                }

                var frame_use_csd = new Frame(Text.CONFIG_DIALOG_HEADER_CSD);
                {
                    var frame_use_csd_box = new Box(Orientation.HORIZONTAL, 0);
                    {
                        radio_use_csd_yes = new RadioButton.with_label(null, Text.DIALOG_YES);
                        {
                            if (options.use_csd) {
                                radio_use_csd_yes.active = true;
                            }
                            radio_use_csd_yes.toggled.connect(() => {
                                    _use_csd = true;
                                });
                        }

                        radio_use_csd_no = new RadioButton.with_label_from_widget(radio_use_csd_yes, Text.DIALOG_NO);
                        {
                            if (!options.use_csd) {
                                radio_use_csd_no.active = true;
                            }
                            radio_use_csd_no.toggled.connect(() => {
                                    _use_csd = false;
                                });
                        }

                        frame_use_csd_box.pack_start(radio_use_csd_yes);
                        frame_use_csd_box.pack_start(radio_use_csd_no);
                    }
                    frame_use_csd.add(frame_use_csd_box);
                }

                config_dialog_vbox.margin = 5;
                config_dialog_vbox.pack_start(frame_audio_choice);
                config_dialog_vbox.pack_start(frame_thumbnail_size);
                config_dialog_vbox.pack_start(frame_playlist_image_size);
                config_dialog_vbox.pack_start(frame_use_csd);
            }

            config_dialog.get_content_area().add(config_dialog_vbox);

            config_dialog.response.connect((response_id) => {
                    switch (response_id) {
                    case ResponseType.ACCEPT:
                        options.ao_type = _ao_type;
                        options.thumbnail_size = (int)spin_thumbnail_size.value;
                        options.playlist_image_size = (int)spin_playlist_image_size.value;
                        if (artwork.pixbuf != null) {
                            artwork.pixbuf = MyUtils.PixbufUtils.scale(current_playing_artwork,
                                                                       options.thumbnail_size);
                        }
                        playlist.resize_artworks(options.playlist_image_size);
                        debug("_use_csd: " + (_use_csd ? "true" : "false"));
                        debug("options.use_csd: " + (options.use_csd ? "true" : "false"));
                        if (options.use_csd != _use_csd) {
                            options.use_csd = _use_csd;
                        }

                        break;

                    case ResponseType.CANCEL:
                        switch (options.ao_type) {
                        case "alsa":
                            radio_audio_alsa.active = true;
                            break;

                        case "pulse":
                            radio_audio_pulse.active = true;
                            break;
                        }
                                    
                        if (options.use_csd) {
                            radio_use_csd_yes.active = true;
                        } else {
                            radio_use_csd_no.active = true;
                        }

                        break;
                    }
                    config_dialog.visible = false;
                });

            config_dialog.destroy.connect(() => {
                    config_dialog = null;
                });

            config_dialog.show_all();
        }
    } else {
        config_dialog.visible = true;
    }
}

void add_bookmark(string file_path) {
    string file_name = file_path.slice(file_path.last_index_of_char('/') + 1, file_path.length);
    TreeStore temp_store = (TreeStore)bookmark_tree.model;
    dirs.append(file_path);
    TreeIter temp_iter;
    temp_store.append(out temp_iter, bookmark_root);
    temp_store.set(temp_iter,
                   0, IconName.Symbolic.FOLDER,
                   1, file_name,
                   2, file_path,
                   3, MenuType.FOLDER,
                   4, Text.EMPTY);
}

bool playlist_exists(string name) {
    TreeStore store = (TreeStore) bookmark_tree.model;
    if(store.iter_has_child(playlist_root)) {
        TreeIter iter;
        store.iter_children(out iter, playlist_root);
        do {
            Value val;
            store.get_value(iter, 1, out val);
            string val_name = (string) val;
            if (val_name == name) {
                return true;
            }
        } while (store.iter_next(ref iter));
    }
    return false;
}

void save_playlist(List<string> file_path_list) {
    if (save_playlist_dialog == null) {
        Entry playlist_name_entry;
        List<string> copy_of_list = file_path_list.copy_deep((src) => {
                return ((string)src).dup();
            });
        save_playlist_dialog = new Dialog.with_buttons(PROGRAM_NAME + ": save playlist",
                                                main_win,
                                                DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
                                                Text.DIALOG_OK,
                                                ResponseType.ACCEPT,
                                                Text.DIALOG_CANCEL,
                                                ResponseType.CANCEL);
        {
            var save_playlist_dialog_hbox = new Box(Orientation.HORIZONTAL, 5);
            {
                var label = new Label(Text.PLAYLIST_SAVE_NAME);
                playlist_name_entry = new Entry();
                save_playlist_dialog_hbox.pack_start(label);
                save_playlist_dialog_hbox.pack_start(playlist_name_entry);
            }
            
            save_playlist_dialog.get_content_area().add(save_playlist_dialog_hbox);

            save_playlist_dialog.response.connect((response_id) => {
                    switch (response_id) {
                    case ResponseType.ACCEPT:
                        string playlist_name = playlist_name_entry.text;
                        string playlist_path = get_playlist_path_from_name(playlist_name);
                        TreeStore temp_store = (TreeStore)bookmark_tree.model;
                        TreeIter temp_iter;
                        temp_store.append(out temp_iter, playlist_root);
                        temp_store.set(temp_iter,
                                       0, IconName.Symbolic.AUDIO_FILE,
                                       1, playlist_name,
                                       2, playlist_path,
                                       3, MenuType.PLAYLIST_NAME,
                                       4, Text.EMPTY);
                        debug("playlist name was saved: %s", playlist_name);
                        overwrite_playlist_file(playlist_name, copy_of_list);
                        playlist.name = playlist_name;
                        break;

                    case ResponseType.CANCEL:
                        break;
                    }
                    playlist_name_entry.text = Text.EMPTY;
                    save_playlist_dialog.visible = false;
                });

            save_playlist_dialog.destroy.connect(() => {
                    save_playlist_dialog = null;
                });

            save_playlist_dialog.show_all();
        }
    } else {
        save_playlist_dialog.visible = true;
    }
}

void overwrite_playlist_file(string playlist_name, List<string> file_path_list) {
    string playlist_file_path = get_playlist_path_from_name(playlist_name);
    string playlist_file_contents = "";
    foreach (string file_path in file_path_list) {
        debug("overwrite_playlist_file: path=%s", file_path);
        playlist_file_contents += file_path + "\n";
    }
    debug("Begin new saved playlist contents:%s", playlist_file_path);
    debug(playlist_file_contents);
    debug("End new saved playlist contents");
    try {
        FileUtils.set_contents(playlist_file_path, playlist_file_contents);
        debug("playlist file has been saved");
    } catch (Error e) {
        stderr.printf(Text.ERROR_WRITE_CONFIG);
        Process.exit(1);
    }
}

void load_playlist_from_file(string playlist_name, string playlist_path) {
    header_switch_button.sensitive = true;
    finder_add_button.sensitive = true;
    playlist.name = playlist_name;
    playlist.load_list_from_file(playlist_path);
    var file_path_list = playlist.get_file_path_list();
    music.start(ref file_path_list, options.ao_type);
    stack.show_playlist();
}

string get_playlist_path_from_name(string name) {
    return Environment.get_home_dir() + "/." + PROGRAM_NAME + "/" + name + ".m3u";
}

void playlist_save_action() {
    if (stack.finder_is_visible()) {
        add_bookmark(finder.dir_path);
    } else if (stack.playlist_is_visible()) {
        if (playlist.name == null) {
            save_playlist(playlist.get_file_path_list());
        } else if (playlist_exists(playlist.name)) {
            if (confirm(Text.CONFIRM_OVERWRITE.printf(playlist.name))) {
                overwrite_playlist_file(playlist.name, playlist.get_file_path_list());
            } else {
                save_playlist(playlist.get_file_path_list());
            }
        }
    }
}

int main(string[] args) {
    //----------------------------------------------------------------------------------
    // confirm existence of mplayer command.
    //----------------------------------------------------------------------------------
    if (Posix.system("mplayer") != 0) {
        stderr.printf(Text.ERROR_NO_MPLAYER);
        Process.exit(1);
    }

    //----------------------------------------------------------------------------------
    // initialization of global variables
    //----------------------------------------------------------------------------------
    dirs = new List<string>();

    file_info_copy_func = (a) => {
        DFileInfo b = new DFileInfo();
        b.dir = a.dir;
        b.name = a.name;
        b.path = a.path;
        b.album = a.album;
        b.artist = a.artist;
        b.comment = a.comment;
        b.genre = a.genre;
        b.title = a.title;
        b.track = a.track;
        b.disc = a.disc;
        b.date = a.date;
        b.time_length = a.time_length;
        b.artwork = a.artwork;
        return b;
    };

    string_compare_func = (a, b) => {
        return a.collate(b);
    };

    print_message_of_send_mplayer_command = true;

    //----------------------------------------------------------------------------------
    // reading config files
    //----------------------------------------------------------------------------------
    string config_dir_path = Environment.get_home_dir() + "/." + PROGRAM_NAME;
    string config_file_path = config_dir_path + "/settings.ini";
    string config_file_contents;
    debug("config_dir: %s", config_dir_path);
    options.ao_type = "pulse";
    options.use_csd = true;
    options.thumbnail_size = 80;
    options.show_thumbs_at = ShowThumbsAt.ALBUMS;
    options.playlist_image_size = 52;
    options.icon_size = 128;
    options.last_playlist_name = "";
    
    current_dir = null;

    try {
        if (!FileUtils.test(config_dir_path, FileTest.EXISTS)) {
            File dir = File.new_for_path(config_dir_path);
            dir.make_directory_with_parents();
        }
        
        if (FileUtils.test(config_file_path, FileTest.EXISTS)) {
            FileUtils.get_contents(config_file_path, out config_file_contents);

            string[] config_file_lines = config_file_contents.split("\n", -1);

            foreach (string line in config_file_lines) {
                string[] pair = line.split("=", 2);
                switch (pair[0]) {
                case "dir":
                    dirs.append(pair[1]);
                    break;

                case "ao_type":
                    options.ao_type = pair[1];
                    break;

                case "thumbnail_size":
                    options.thumbnail_size = int.parse(pair[1]);
                    break;

                case "use_csd":
                    if (pair[1] == "true") {
                        options.use_csd = true;
                    } else if (pair[1] == "false") {
                        options.use_csd = false;
                    }
                    break;

                case "cwd":
                    current_dir = pair[1];
                    break;

                case "playlist_image_size":
                    options.playlist_image_size = int.parse(pair[1]);
                    break;

                case "icon_size":
                    options.icon_size = int.parse(pair[1]);
                    break;

                case "last_playlist_name":
                    options.last_playlist_name = pair[1];
                    break;
                }
            }
        }

        if (dirs.length() == 0) {
            dirs.append(Environment.get_home_dir() + "/" + Text.DIR_NAME_MUSIC);
        }
    } catch(Error e) {
        dirs.append(Environment.get_home_dir() + "/" + Text.DIR_NAME_MUSIC);
    }

    //----------------------------------------------------------------------------------
    // Reading command line options
    //----------------------------------------------------------------------------------
    for (int i = 1; i < args.length; i++) {
        switch (args[i]) {
        case "-a":
            i++;
            if (args[i] != "alsa" && args[i] != "pulse") {
                Process.exit(1);
            }

            options.ao_type = args[i];
            break;

        default:
            stderr.printf(Text.ERROR_UNKOWN_OPTION, PROGRAM_NAME, args[i]);
            Process.exit(1);
        }
    }

    //----------------------------------------------------------------------------------
    // create temporary working directory
    //----------------------------------------------------------------------------------
    File tmp_dir = File.new_for_path("/tmp/" + PROGRAM_NAME);
    if (!FileUtils.test("/tmp/" + PROGRAM_NAME, FileTest.EXISTS)) {
        try {
            tmp_dir.make_directory();
        } catch(Error e) {
            stderr.printf(Text.ERROR_FAIL_TMP_DIR);
            Process.exit(1);
        }
    }

    //----------------------------------------------------------------------------------
    // Setting place of a CSS file
    //----------------------------------------------------------------------------------
    string css_path = config_dir_path + "/main.css";
    if (!FileUtils.test(css_path, FileTest.EXISTS)) {
        string css_contents = Text.DEFAULT_CSS;
        FileUtils.set_contents(css_path, css_contents);
    }
        
    Gtk.init(ref args);

    //----------------------------------------------------------------------------------
    // Initialization of local variables
    //----------------------------------------------------------------------------------

    Revealer bookmark_revealer = null;
    Button music_view_close_button = null;
    
    TreeViewColumn bookmark_title_col = null;

    var screen = Gdk.Screen.get_default();

    debug("get screen: " + (screen != null ? "ok." : "failed"));
    
    max_width = screen.get_width();
    max_height = screen.get_height();

    debug("Max width of the display: " + max_width.to_string());
    debug("Max height of the display: " + max_height.to_string());

    window_default_height = (int) (max_height * 0.7);
    window_default_width = int.min((int) (max_width * 0.5), (int) (window_default_height * 1.3));
    
    artwork_max_size = int.min(max_width, max_height);

    //----------------------------------------------------------------------------------
    // Loading icon images
    //----------------------------------------------------------------------------------

    IconTheme icon_theme = Gtk.IconTheme.get_default();
    try {
        file_pixbuf = icon_theme.load_icon(IconName.AUDIO_FILE, 64, 0);
        cd_pixbuf = icon_theme.load_icon(IconName.MEDIA_OPTICAL, 64, 0);
        folder_pixbuf = icon_theme.load_icon(IconName.FOLDER_MUSIC, 64, 0);
        if (folder_pixbuf == null) {
            folder_pixbuf = icon_theme.load_icon(IconName.FOLDER, 64, 0);
        }
        parent_pixbuf = icon_theme.load_icon(IconName.GO_UP, 64, 0);
    } catch (Error e) {
        stderr.printf(Text.ERROR_LOAD_ICON);
        Process.exit(1);
    }

    //----------------------------------------------------------------------------------
    // Creating window header
    //----------------------------------------------------------------------------------

    win_header = null;
 
    if (options.use_csd) {
        win_header = new HeaderBar();
        {
            var header_box = new Box(Orientation.HORIZONTAL, 0);
            {
                header_switch_button = new Button.from_icon_name(IconName.Symbolic.VIEW_LIST, IconSize.BUTTON);
                {
                    header_switch_button.get_style_context().add_class(StyleClass.TITLEBUTTON);
                    header_switch_button.add(new Image.from_icon_name(IconName.Symbolic.VIEW_LIST, IconSize.BUTTON));
                    header_switch_button.clicked.connect(() => {
                            if (stack.finder_is_visible()) {
                                DFileInfo file_info = playlist.track_data();

                                if (options.use_csd) {
                                    if (file_info.title != null) {
                                        win_header.set_title(file_info.title);
                                    } else {
                                        win_header.set_title(file_info.name);
                                    }
                                } else {
                                    if (file_info.title != null) {
                                        playlist_view_dir_label.label = Text.MARKUP_BOLD_ITALIC.printf(file_info.title);
                                    } else {
                                        playlist_view_dir_label.label = Text.MARKUP_BOLD_ITALIC.printf(file_info.name);
                                    }
                                }
                                if (current_playing_artwork != null) {
                                    artwork_button.visible = true;
                                }
                                music_view_artwork.visible = false;
                                stack.show_playlist();
                                (header_switch_button.image as Image).icon_name = IconName.Symbolic.GO_PREVIOUS;
                            } else if (stack.playlist_is_visible()) {
                                if (options.use_csd) {
                                    win_header.set_title(finder.dir_path);
                                } else {
                                    main_win.title = finder.dir_path;
                                }
                                if (current_playing_artwork != null) {
                                    artwork_button.visible = true;
                                }
                                music_view_artwork.visible = false;
                                stack.show_finder();
                                (header_switch_button.image as Image).icon_name = IconName.Symbolic.VIEW_LIST;
                            }
                        });
                }

                header_add_button = new Button.from_icon_name(IconName.Symbolic.BOOKMARK_NEW, IconSize.BUTTON);
                {
                    header_add_button.get_style_context().add_class(StyleClass.TITLEBUTTON);
                    header_add_button.add(new Image.from_icon_name(IconName.Symbolic.BOOKMARK_NEW, IconSize.BUTTON));
                    header_add_button.tooltip_text = Text.TOOLTIP_SAVE_PLAYLIST;
                    header_add_button.clicked.connect(() => {
                            playlist_save_action();
                        });
                }
                

#if PREPROCESSOR_DEBUG
                var debug_print_music_button = new Button.with_label("d1");
                {
                    debug_print_music_button.get_style_context().add_class(StyleClass.TITLEBUTTON);
                    debug_print_music_button.clicked.connect(() => {
                            music.debug_print_current_playlist();
                        });
                }
#endif
                header_box.add(header_switch_button);
                header_box.add(header_add_button);
                
#if PREPROCESSOR_DEBUG
                // debug
                header_box.add(debug_print_music_button);
#endif
            }

            var header_fold_button = new Button();
            {
                header_fold_button.get_style_context().add_class(StyleClass.TITLEBUTTON);
                header_fold_button.add(new Image.from_icon_name(IconName.Symbolic.GO_UP, IconSize.BUTTON));
                header_fold_button.sensitive = true;
                header_fold_button.clicked.connect(() => {
                        if (stack.stack_is_visible()) {
                            saved_main_win_width = main_win.get_allocated_width();
                            saved_main_win_height = main_win.get_allocated_height();
                            main_win.resize(saved_main_win_width, 1);
                            header_fold_button.image = new Image.from_icon_name(IconName.Symbolic.GO_DOWN, IconSize.BUTTON);
                            stack.hide_stack();
                            prev_track_button.visible = false;
                            next_track_button.visible = false;
                            toggle_repeat_button.visible = false;
                            toggle_shuffle_button.visible = false;
                            header_switch_button.sensitive = false;
                            artwork_button.sensitive = false;
                        } else {
                            main_win.resize(main_win.get_allocated_width(), saved_main_win_height);
                            header_fold_button.image = new Image.from_icon_name(IconName.Symbolic.GO_UP, IconSize.BUTTON);
                            stack.show_stack();
                            prev_track_button.visible = true;
                            next_track_button.visible = true;
                            toggle_repeat_button.visible = true;
                            toggle_shuffle_button.visible = true;
                            header_switch_button.sensitive = true;
                            artwork_button.sensitive = true;
                        }
                    });

            }

            var header_config_button = new Button();
            {
                header_config_button.get_style_context().add_class(StyleClass.TITLEBUTTON);
                header_config_button.add(new Image.from_icon_name(IconName.Symbolic.APPLICATIONS_SYSTEM, IconSize.BUTTON));
                header_config_button.sensitive = true;
                header_config_button.clicked.connect(() => {
                        show_config_dialog(main_win);
                    });
            }
            
            var header_about_button = new Button();
            {
                header_about_button.get_style_context().add_class(StyleClass.TITLEBUTTON);
                header_about_button.add(new Image.from_icon_name(IconName.Symbolic.HELP_ABOUT, IconSize.BUTTON));
                header_about_button.sensitive = true;
                header_about_button.clicked.connect(() => {
                        show_about_dialog(main_win);
                    });
            }
            
            win_header.show_close_button = true;
            win_header.title = PROGRAM_NAME;
            win_header.has_subtitle = false;
            win_header.pack_start(header_box);
            win_header.pack_end(header_fold_button);
            win_header.pack_end(header_about_button);
//            win_header.pack_end(header_config_button);
        }
    }

    //----------------------------------------------------------------------------------
    // Creating control bar
    //----------------------------------------------------------------------------------
    controller = new Box(Orientation.HORIZONTAL, 2);
    {
        artwork_button = new Button();
        {
            artwork = new Image();
            {
                artwork.margin = 0;
            }

            artwork_button.margin = 0;
            artwork_button.relief = ReliefStyle.NORMAL;
            artwork_button.get_style_context().add_class(StyleClass.FLAT);
            artwork_button.add(artwork);
            artwork_button.clicked.connect(() => {
                    if (options.use_csd) {
                        win_header.set_title(music_title.label);
                    } else {
                        main_win.title = music_title.label;
                    }
                    artwork_button.visible = false;
                    music_view_overlay.visible = true;

                    Timeout.add(300, () => {
                            debug("enter timeout artwork_button.clicked");
                            int size = int.min(music_view_container.get_allocated_width(),
                                               music_view_container.get_allocated_height());
                            music_view_artwork.pixbuf = MyUtils.PixbufUtils.scale(current_playing_artwork, size);
                            music_view_artwork.visible = true;
                            header_switch_button.sensitive = false;
                            finder_add_button.sensitive = false;
                            return Source.REMOVE;
                        });
                });
        }

        var controller_second_box = new Box(Orientation.HORIZONTAL, 2);
        {
            play_pause_button = new ToolButton(new Image.from_icon_name(IconName.Symbolic.MEDIA_PLAYBACK_START,
                                                                        IconSize.SMALL_TOOLBAR), null);
            {
                play_pause_button.sensitive = false;
                play_pause_button.clicked.connect(() => {
                        if (music.playing) {
                            debug("play-pause button was clicked. music is playing. pause it.");
                            music.pause();
                            playlist.toggle_status();
                            if (music.paused) {
                                ((Gtk.Image)play_pause_button.icon_widget).icon_name = IconName.Symbolic.MEDIA_PLAYBACK_START;
                            } else {
                                ((Gtk.Image)play_pause_button.icon_widget).icon_name = IconName.Symbolic.MEDIA_PLAYBACK_PAUSE;
                            }
                        } else {
                            finder.change_cursor(Gdk.CursorType.WATCH);
                            Idle.add(() => {
                                    debug("play-pause button was clicked. music is not playing. start it.");
                                    if (stack.finder_is_visible()) {
                                        playlist.new_list_from_path(finder.dir_path);
                                    }
                                    stack.show_playlist();
                                    header_switch_button.sensitive = true;
                                    (header_switch_button.image as Image).icon_name = IconName.GO_PREVIOUS;
                                    var file_path_list = playlist.get_file_path_list();
                                    music.start(ref file_path_list, options.ao_type);
                                    finder.change_cursor(Gdk.CursorType.LEFT_PTR);
                                    return Source.REMOVE;
                                });
                        }
                    });
            }

            next_track_button = new ToolButton(new Image.from_icon_name(IconName.Symbolic.MEDIA_SKIP_FORWARD,
                                                                        IconSize.SMALL_TOOLBAR), null);
            {
                next_track_button.sensitive = false;
                next_track_button.clicked.connect(() => {
                        playlist.move_to_next_track();
                        music.play_next();
                    });
            }

            prev_track_button = new ToolButton(new Image.from_icon_name(IconName.Symbolic.MEDIA_SKIP_BACKWARD,
                                                                        IconSize.SMALL_TOOLBAR), null);
            {
                prev_track_button.sensitive = false;
                prev_track_button.clicked.connect(() => {
                        if (music.playing) {
                            debug("prev playlist.track button was clicked. current time position is %.1f in seconds.",
                                  music_time_position);
                            if (playlist.get_track() == 0 || music_time_position > 1.0) {
                                music.move_pos(0);
                                music_time_position = 0;
                                time_bar.set_value(0.0);
                                time_label_set(0);
                            } else {
                                music.play_prev();
                            }
                        }
                    });
            }

            controller_second_box.valign = Align.CENTER;
            controller_second_box.vexpand = false;
            controller_second_box.margin_right = 10;
            controller_second_box.get_style_context().add_class(StyleClass.LINKED);
            controller_second_box.pack_start(prev_track_button, false, false);
            controller_second_box.pack_start(play_pause_button, false, false);
            controller_second_box.pack_start(next_track_button, false, false);
        }

        var time_bar_box = new Box(Orientation.VERTICAL, 2);
        {
            music_title = new Label("");
            {
                music_title.justify = Justification.LEFT;
                music_title.single_line_mode = false;
                music_title.lines = 4;
                music_title.wrap = true;
                music_title.wrap_mode = Pango.WrapMode.WORD_CHAR;
                music_title.ellipsize = Pango.EllipsizeMode.END;
                music_title.margin_start = 5;
                music_title.margin_end = 5;
            }

            time_bar = new Scale.with_range(Orientation.HORIZONTAL, 0.0, 1.0, 0.01);
            {
                time_bar.set_size_request(-1, 12);
                time_bar.draw_value = false;
                time_bar.has_origin = true;
                time_bar.change_value.connect((scroll_type, value) => {
                        music_time_position = music_total_time_seconds * value;
                        music.move_pos((int) (value * 100));
                        return false;
                    });
            }

            var time_label_box = new Box(Orientation.HORIZONTAL, 0);
            {
                time_label_current = new Label("0:00:00");
                {
                    time_label_current.get_style_context().add_class(StyleClass.TIME_LABEL_CURRENT);
                }
                time_label_rest = new Label("0:00:00");
                {
                    time_label_rest.get_style_context().add_class(StyleClass.TIME_LABEL_REST);
                }
                time_label_box.pack_start(time_label_current, false, false);
                time_label_box.pack_end(time_label_rest, false, false);
            }
            
            time_bar_box.valign = Align.CENTER;
            time_bar_box.pack_start(music_title, false, false);
            time_bar_box.pack_start(time_bar, true, false);
            time_bar_box.pack_start(time_label_box, true, false);
        }

        var controller_third_box = new Box(Orientation.HORIZONTAL, 2);
        {
            var volume_button = new ToolButton(
                new Image.from_icon_name(IconName.Symbolic.AUDIO_VOLUME_MEDIUM, IconSize.SMALL_TOOLBAR), null);
            {
                var popover = new Popover(volume_button);
                {
                    var volume_bar = new Scale.with_range(Orientation.VERTICAL, 0, 100, -1);
                    {
                        volume_bar.set_value(50);
                        volume_bar.has_origin = true;
                        volume_bar.set_inverted(true);
                        volume_bar.draw_value = true;
                        volume_bar.value_pos = PositionType.BOTTOM;
                        volume_bar.margin = 5;
                        volume_bar.value_changed.connect(() => {
                                if (music.playing) {
                                    music.set_volume(volume_bar.get_value());
                                }
                                if (volume_bar.get_value() == 0) {
                                    ((Gtk.Image) volume_button.icon_widget).icon_name = IconName.Symbolic.AUDIO_VOLUME_MUTED;
                                } else if (volume_bar.get_value() < 35) {
                                    ((Gtk.Image) volume_button.icon_widget).icon_name = IconName.Symbolic.AUDIO_VOLUME_LOW;
                                } else if (volume_bar.get_value() < 75) {
                                    ((Gtk.Image) volume_button.icon_widget).icon_name = IconName.Symbolic.AUDIO_VOLUME_MEDIUM;
                                } else {
                                    ((Gtk.Image) volume_button.icon_widget).icon_name = IconName.Symbolic.AUDIO_VOLUME_HIGH;
                                }
                            });

                    }

                    popover.add(volume_bar);
                    popover.modal = true;
                    popover.position = PositionType.TOP;
                    popover.set_size_request(20, 150);
                    volume_bar.show();
                }

                volume_button.clicked.connect(() => {popover.visible = !popover.visible;});
            }

            toggle_shuffle_button = new ToggleButton();
            {
                toggle_shuffle_button.image = new Image.from_icon_name(IconName.Symbolic.MEDIA_PLAYLIST_SHUFFLE,
                                                                       IconSize.SMALL_TOOLBAR);
                toggle_shuffle_button.active = false;
                toggle_shuffle_button.draw_indicator = false;
                toggle_shuffle_button.valign = Align.CENTER;
                toggle_shuffle_button.halign = Align.CENTER;
                toggle_shuffle_button.toggled.connect(() => {
                        playlist.toggle_shuffle();
                        music.toggle_shuffle();
                    });
            }

            toggle_repeat_button = new ToggleButton();
            {
                toggle_repeat_button.image = new Image.from_icon_name(IconName.Symbolic.MEDIA_PLAYLIST_REPEAT,
                                                                      IconSize.SMALL_TOOLBAR);
                toggle_repeat_button.active = false;
                toggle_repeat_button.draw_indicator = false;
                toggle_repeat_button.valign = Align.CENTER;
                toggle_repeat_button.halign = Align.CENTER;
                toggle_repeat_button.toggled.connect(() => {
                        playlist.toggle_repeat();
                        music.toggle_repeat();
                    });
            }

            controller_third_box.valign = Align.CENTER;
            controller_third_box.vexpand = false;
            controller_third_box.margin_right = 10;
            controller_third_box.pack_start(volume_button, false, false);
            controller_third_box.pack_start(toggle_shuffle_button, false, false);
            controller_third_box.pack_start(toggle_repeat_button, false, false);
        }

    controller.margin = 4;
        controller.pack_start(artwork_button, false, false);
        controller.pack_start(controller_second_box, false, false);
        controller.pack_start(time_bar_box, true, true);
        controller.pack_start(controller_third_box, false, false);
    }

    //------------------------------------------------------------------------------
    // Creating finder view and sidebar
    //------------------------------------------------------------------------------
    var finder_paned = new Paned(Orientation.HORIZONTAL);
    {
        //------------------------------------------------------------------------------
        // Creating bookmark tree
        //------------------------------------------------------------------------------
        var bookmark_frame = new Frame(null);
        {
            var bookmark_scrolled = new ScrolledWindow(null, null);
            {
                bookmark_tree = new TreeView();
                {
                    bookmark_title_col = new TreeViewColumn();
                    {
                        var bookmark_icon_cell = new CellRendererPixbuf();
                        var bookmark_label_cell = new CellRendererText();
                        {
                            bookmark_label_cell.family = Text.FONT_FAMILY;
                            bookmark_label_cell.language = Environ.get_variable(Environ.get(), "LANG");
                        }

                        bookmark_title_col.pack_start(bookmark_icon_cell, false);
                        bookmark_title_col.pack_start(bookmark_label_cell, true);
                        bookmark_title_col.add_attribute(bookmark_icon_cell, "icon-name", 0);
                        bookmark_title_col.add_attribute(bookmark_label_cell, "text", 1);
                        bookmark_title_col.set_title("label");
                        bookmark_title_col.sizing = TreeViewColumnSizing.AUTOSIZE;
                        bookmark_title_col.max_width = window_default_width / 4;
                    }

                    var bookmark_del_col = new TreeViewColumn();
                    {
                        var bookmark_del_cell = new CellRendererPixbuf();

                        bookmark_del_col.pack_start(bookmark_del_cell, false);
                        bookmark_del_col.add_attribute(bookmark_del_cell, "icon-name", 4);
                        bookmark_del_col.set_title("del");
                    }

                    var bookmark_store = new TreeStore(5, typeof(string), typeof(string), typeof(string),
                                                       typeof(MenuType), typeof(string));
                    {
                        bookmark_store.append(out bookmark_root, null);
                        bookmark_store.set(bookmark_root,
                                           0, IconName.Symbolic.USER_BOOKMARKS, 1, Text.MENU_BOOKMARK,
                                           2, "", 3, MenuType.BOOKMARK, 4, "");

                        TreeIter bm_iter;
                        bookmark_store.append(out playlist_root, null);
                        bookmark_store.set(playlist_root,
                                           0, IconName.Symbolic.MEDIA_OPTICAL, 1, Text.MENU_PLAYLIST,
                                           2, "", 3, MenuType.PLAYLIST_HEADER, 4, "");
                        bookmark_store.append(out bm_iter, null);
                        bookmark_store.set(bm_iter, 0, null, 1, null, 2, null,
                                           3, MenuType.SEPARATOR, 4, "");
                        bookmark_store.append(out bm_iter, null);
                        bookmark_store.set(bm_iter, 0, IconName.Symbolic.FOLDER_OPEN, 1, Text.MENU_CHOOSE_DIR,
                                           2, null, 3, MenuType.CHOOSER, 4, "");
                        if (!options.use_csd) {
                            bookmark_store.append(out bm_iter, null);
                            bookmark_store.set(bm_iter,
                                               0, IconName.Symbolic.PREFERENCES_SYSTEM, 1, Text.MENU_CONFIG,
                                               2, null, 3, MenuType.CONFIG, 4, "");
                            bookmark_store.append(out bm_iter, null);
                            bookmark_store.set(bm_iter,
                                               0, IconName.Symbolic.HELP_FAQ, 1, Text.MENU_ABOUT,
                                               2, null, 3, MenuType.ABOUT, 4, "");
                            bookmark_store.append(out bm_iter, null);
                            bookmark_store.set(bm_iter,
                                               0, IconName.Symbolic.EXIT, 1, Text.MENU_QUIT,
                                               2, null, 3, MenuType.QUIT, 4, "");
                        }
                    }

                    Gtk.Callback menu_bookmark_reset = (bm) => {
                        TreeIter bm_iter;
                        bookmark_store.iter_children(out bm_iter, bookmark_root);

                        while (bookmark_store.iter_is_valid(bm_iter)) {
                            bookmark_store.remove(ref bm_iter);
                        }

                        foreach (string dir in dirs) {
                            string dir_basename = dir.slice(dir.last_index_of_char('/') + 1, dir.length);
                            bookmark_store.append(out bm_iter, bookmark_root);
                            bookmark_store.set(bm_iter, 0, IconName.Symbolic.FOLDER, 1, dir_basename, 2, dir,
                                               3, MenuType.FOLDER, 4, "");
                        }

                        bookmark_store.iter_children(out bm_iter, playlist_root);

                        while (bookmark_store.iter_is_valid(bm_iter)) {
                            bookmark_store.remove(ref bm_iter);
                        }

                        Dir dir;
                        try {
                            dir = Dir.open(config_dir_path, 0);
                        } catch (Error e) {
                            stderr.printf(Text.ERROR_OPEN_PLAYLIST_FILE);
                            Process.exit(1);
                        }

                        string file_name;
                        while ((file_name = dir.read_name()) != null) {
                            if (MyUtils.FilePathUtils.extension_of(file_name) == "m3u") {
                                string playlist_name = MyUtils.FilePathUtils.remove_extension(file_name);
                                bookmark_store.append(out bm_iter, playlist_root);
                                bookmark_store.set(bm_iter, 0, IconName.Symbolic.AUDIO_FILE,
                                                   1, playlist_name,
                                                   2, get_playlist_path_from_name(playlist_name),
                                                   3, MenuType.PLAYLIST_NAME, 4, "");
                            }
                        }
                    };

                    bookmark_tree.activate_on_single_click = true;
                    bookmark_tree.headers_visible = false;
                    bookmark_tree.hover_selection = true;
                    bookmark_tree.reorderable = false;
                    bookmark_tree.show_expanders = true;
                    bookmark_tree.enable_tree_lines = false;
                    bookmark_tree.level_indentation = 0;

                    bookmark_tree.set_model(bookmark_store);
                    bookmark_tree.insert_column(bookmark_del_col, 1);
                    bookmark_tree.insert_column(bookmark_title_col, 0);

                    menu_bookmark_reset(bookmark_tree);

                    bookmark_tree.set_row_separator_func((model, iter) => {
                            Value menu_type;
                            model.get_value(iter, 3, out menu_type);
                            return ((MenuType) menu_type == MenuType.SEPARATOR);
                        });

                    bookmark_tree.get_selection().changed.connect(() => {
                            TreeSelection bookmark_selection = bookmark_tree.get_selection();
                            TreeStore? temp_store = (TreeStore) bookmark_tree.model;

                            temp_store.foreach((model, path, iter) => {
                                    Value type;
                                    temp_store.get_value(iter, 3, out type);
                                    if ((MenuType) type == MenuType.FOLDER || (MenuType) type == MenuType.PLAYLIST_NAME) {
                                        string icon_name = "";
                                        if (dirs.length() > 0 && bookmark_selection.iter_is_selected(iter)) {
                                            icon_name = IconName.Symbolic.LIST_REMOVE;
                                        } else {
                                            icon_name = "";
                                        }
                                        temp_store.set_value(iter, 4, icon_name);
                                    }
                                    return false;
                                });
                        });

                    bookmark_tree.row_activated.connect((path, column) => {
                            Value dir_path;
                            Value bookmark_name;
                            TreeIter bm_iter;

                            debug("bookmark_tree_row_activated.");
                            bookmark_tree.model.get_iter(out bm_iter, path);
                            bookmark_tree.model.get_value(bm_iter, 3, out bookmark_name);

                            switch ((MenuType) bookmark_name) {
                            case MenuType.BOOKMARK:
                                if (bookmark_tree.is_row_expanded(path)) {
                                    bookmark_tree.collapse_row(path);
                                } else {
                                    bookmark_tree.expand_row(path, false);
                                }
                                break;
                                
                            case MenuType.FOLDER:
                                bookmark_tree.model.get_value(bm_iter, 2, out dir_path);

                                if (column.get_title() != "del") {
                                    finder.change_dir((string) dir_path);
                                    finder_add_button.sensitive = true;
                                    current_dir = (string) dir_path;
                                    
                                    if (options.use_csd) {
                                        win_header.set_title(PROGRAM_NAME + ": " + current_dir);
                                    }
                                } else {
                                    if (dirs.length() > 1) {
                                        if (confirm(Text.CONFIRM_REMOVE_BOOKMARK)) {
                                            dirs.remove_link(dirs.nth(path.get_indices()[1]));
                                            ((TreeStore)bookmark_tree.model).remove(ref bm_iter);
                                        }
                                    }
                                }
                                break;
                            case MenuType.PLAYLIST_HEADER:
                                if (bookmark_tree.is_row_expanded(path)) {
                                    bookmark_tree.collapse_row(path);
                                } else {
                                    bookmark_tree.expand_row(path, false);
                                }
                                break;
                            case MenuType.PLAYLIST_NAME:
                                Value val1;
                                Value val2;
                                bookmark_tree.model.get_value(bm_iter, 1, out val1);
                                bookmark_tree.model.get_value(bm_iter, 2, out val2);
                                string playlist_name = (string) val1;
                                string playlist_path = (string) val2;

                                if (column.get_title() != "del") {
                                    if (music.playing) {
                                        music.quit();
                                    }
                                    Idle.add(() => {
                                            if (music.playing) {
                                                return Source.CONTINUE;
                                            } else {
                                                load_playlist_from_file(playlist_name, playlist_path);
                                                return Source.REMOVE;
                                            }
                                        });
                                } else {
                                    if (confirm(Text.CONFIRM_REMOVE_PLAYLIST)) {
                                        ((TreeStore)bookmark_tree.model).remove(ref bm_iter);
                                        FileUtils.remove(playlist_path);
                                    }
                                }
                                break;
                            case MenuType.CHOOSER:
                                var file_chooser = new FileChooserDialog (Text.DIALOG_OPEN_FILE, main_win,
                                                                          FileChooserAction.SELECT_FOLDER,
                                                                          Text.DIALOG_CANCEL, ResponseType.CANCEL,
                                                                          Text.DIALOG_OPEN, ResponseType.ACCEPT);
                                if (file_chooser.run () == ResponseType.ACCEPT) {
                                    current_dir = file_chooser.get_filename();
                                    debug("selected file path: %s", current_dir);
                                    finder.change_dir(current_dir);
                                    win_header.set_title(current_dir);
                                    finder_add_button.sensitive = true;
                                }
                                file_chooser.destroy ();
                                break;
                            case MenuType.CONFIG:
                                show_config_dialog(main_win);
                                break;
                            case MenuType.ABOUT:
                                show_about_dialog(main_win);
                                break;
                            case MenuType.QUIT:
                                application_quit();
                                break;
                            }
                        });

                    bookmark_tree.expand_all();
                }

                bookmark_scrolled.shadow_type = ShadowType.NONE;
                bookmark_scrolled.hscrollbar_policy = PolicyType.NEVER;
                bookmark_scrolled.add(bookmark_tree);
            }

            bookmark_frame.set_shadow_type(ShadowType.NONE);
            bookmark_frame.get_style_context().add_class(StyleClass.SIDEBAR);
            bookmark_frame.add(bookmark_scrolled);
        }

        //------------------------------------------------------------------------------
        // Creating finder (a file chooser)
        //------------------------------------------------------------------------------
        var finder_box = new Box(Orientation.VERTICAL, 4);
        {
            var finder_toolbar = new Box(Orientation.HORIZONTAL, 4);
            {
                finder_parent_button = new Button.from_icon_name(IconName.Symbolic.GO_UP, IconSize.BUTTON);
                {
                    finder_parent_button.tooltip_text = Text.TOOLTIP_FINDER_GO_UP;
                    finder_parent_button.clicked.connect(() => {
                            string path = File.new_for_path(current_dir).get_parent().get_path();
                            finder.change_dir(path);
                            finder.file_button_clicked(path);
                        });
                }
                
                var finder_zoom_box = new Box(Orientation.HORIZONTAL, 0);
                {
                    finder_zoomin_button = new Button.from_icon_name(IconName.Symbolic.ZOOM_IN,
                                                                     IconSize.BUTTON);
                    {
                        finder_zoomin_button.get_style_context().add_class(StyleClass.TITLEBUTTON);
                        finder_zoomin_button.tooltip_text = Text.TOOLTIP_FINDER_ZOOMIN;
                        finder_zoomin_button.clicked.connect(() => {
                                finder.zoom_in();
                            });
                    }

                    finder_zoomout_button = new Button.from_icon_name(IconName.Symbolic.ZOOM_OUT,
                                                                      IconSize.BUTTON);
                    {
                        finder_zoomout_button.get_style_context().add_class(StyleClass.TITLEBUTTON);
                        finder_zoomout_button.tooltip_text = Text.TOOLTIP_FINDER_ZOOMOUT;
                        finder_zoomout_button.clicked.connect(() => {
                                finder.zoom_out();
                            });
                    }

                    finder_zoom_box.pack_start(finder_zoomin_button, false, false);
                    finder_zoom_box.pack_start(finder_zoomout_button, false, false);
                }
                
                finder_location = new Entry();
                {
                    finder_location.activate.connect(() => {
                            string text = finder_location.get_text();
                            if (FileUtils.test(text, FileTest.IS_DIR)) {
                                finder.change_dir(text);
                            }
                        });
                }

                finder_refresh_button = new Button.from_icon_name(IconName.Symbolic.VIEW_REFRESH, IconSize.BUTTON);
                {
                    finder_refresh_button.get_style_context().add_class(StyleClass.TITLEBUTTON);
                    finder_refresh_button.tooltip_text = Text.TOOLTIP_REFRESH_FINDER;
                    finder_refresh_button.clicked.connect(() => {
                            finder.change_dir(current_dir);
                        });
                }
                
                finder_add_button = new Button.from_icon_name(IconName.Symbolic.BOOKMARK_NEW, IconSize.BUTTON);
                {
                    finder_add_button.get_style_context().add_class(StyleClass.TITLEBUTTON);
                    finder_add_button.tooltip_text = Text.TOOLTIP_SAVE_FINDER;
                    finder_add_button.clicked.connect(() => {
                            playlist_save_action();
                        });
                }
                
                finder_toolbar.pack_start(finder_parent_button, false, false);
                finder_toolbar.pack_start(finder_zoom_box, false, false);
                finder_toolbar.pack_start(finder_location, true, true);
                finder_toolbar.pack_start(finder_refresh_button, false, false);
                finder_toolbar.pack_start(finder_add_button, false, false);
            }
            
            var finder_overlay = new Overlay();
            {
                finder = new Mpd.Finder();
                {
                    finder.set_default_icon_size(options.icon_size);

                    finder.dir_changed.connect((path) => {
                            finder_location.buffer.set_text(path.data);
                            finder_add_button.sensitive = true;
                        });
                    
                    finder.bookmark_button_clicked.connect((file_path) => {
                            add_bookmark(file_path);
                        });

                    finder.play_button_clicked.connect((file_path) => {

                            finder.change_cursor(Gdk.CursorType.WATCH);
                    
                            if (music.playing) {
                                music.quit();
                            }
                    
                            Idle.add(() => {
                                    if (music.playing) {
                                        return Source.CONTINUE;
                                    } else {
                                        debug("file_path: %s", file_path);
                                        playlist.new_list_from_path(file_path);
                                        var file_path_list = playlist.get_file_path_list();
                                        if (FileUtils.test(file_path, FileTest.IS_REGULAR)) {
                                            music.start(ref file_path_list, options.ao_type);
                                            int index = playlist.get_index_from_path(file_path);
                                            if (index > 0) {
                                                music.play_next(index);
                                            }
                                        } else {
                                            music.start(ref file_path_list, options.ao_type);
                                        }
                                        ((Gtk.Image)play_pause_button.icon_widget).icon_name = IconName.Symbolic.MEDIA_PLAYBACK_PAUSE;
                                        (header_switch_button.image as Image).icon_name = IconName.Symbolic.GO_PREVIOUS;
                                        header_switch_button.sensitive = true;
                                        stack.show_playlist();
                                        finder.change_cursor(Gdk.CursorType.LEFT_PTR);
                                        return Source.REMOVE;
                                    }
                                });
                        });

                    finder.add_button_clicked.connect((file_path) => {
                            playlist.append_list_from_path(file_path);
                            List<string> file_list = playlist.get_file_path_list();
                            playlist.changed(file_list);
                        });

                    finder.icon_image_resized.connect((icon_size) => {
                            options.icon_size = icon_size;
                        });

                    finder.file_button_clicked.connect((file_path) => {
                            if (FileUtils.test(file_path, FileTest.IS_DIR)) {
                                current_dir = file_path;
                                win_header.set_title(current_dir);
                            }
                        });

                    finder.use_popover = false;
                }

                var go_playlist_button = new Button.from_icon_name(IconName.GO_NEXT);
                {
                    go_playlist_button.halign = Align.END;
                    go_playlist_button.valign = Align.CENTER;
                    go_playlist_button.clicked.connect(() => {
                            stack.show_playlist();
                        });
                }

                finder_overlay.add(finder);
                if (!options.use_csd) {
                    finder_overlay.add_overlay(go_playlist_button);
                }
            }

            finder_box.pack_start(finder_toolbar, false, false);
            finder_box.pack_start(finder_overlay, true, true);
        }
        
        finder_paned.pack1(bookmark_frame, false, true);
        finder_paned.pack2(finder_box, true, true);
    }

    //----------------------------------------------------------------------------------
    // Creating playlist view
    //----------------------------------------------------------------------------------

    var playlist_vbox = new Box(Orientation.HORIZONTAL, 0);
    {
        var playlist_toolbar = new Box(Orientation.VERTICAL, 0);
        {
            var back_button = new ToolButton(new Image.from_icon_name(IconName.Symbolic.GO_PREVIOUS,
                                                                      IconSize.SMALL_TOOLBAR),
                                             null);
            {
                back_button.halign = Align.CENTER;
                back_button.valign = Align.START;
                back_button.tooltip_text = Text.TOOLTIP_SHOW_FINDER;
                back_button.clicked.connect(() => {
                        stack.show_finder();
                    });
            }

            var save_button = new ToolButton(new Image.from_icon_name(IconName.Symbolic.DOCUMENT_SAVE,
                                                                      IconSize.SMALL_TOOLBAR),
                                             null);
            {
                save_button.halign = Align.CENTER;
                save_button.valign = Align.START;
                save_button.tooltip_text = Text.TOOLTIP_SAVE_PLAYLIST;
                save_button.clicked.connect(() => {
                        playlist_save_action();
                    });
            }

            playlist_toolbar.pack_start(back_button, false, false);
            playlist_toolbar.pack_start(save_button, false, false);
        }
        
        var playlist_view_container = new ScrolledWindow(null, null);
        {
            playlist = new PlaylistBox();
            {
                playlist.image_size = options.playlist_image_size;
                playlist.list_box.row_activated.connect((row) => {
                        int index = row.get_index();
                        debug("playlist view was clicked (row_activated at %u).", index);
                        int step = ((int) index) - ((int) playlist.get_track());
                        
                        if (step == 0) {
                            music.pause();
                            playlist.toggle_status();
                            if (music.paused) {
                                ((Gtk.Image)play_pause_button.icon_widget).icon_name = IconName.Symbolic.MEDIA_PLAYBACK_START;
                            } else {
                                ((Gtk.Image)play_pause_button.icon_widget).icon_name = IconName.Symbolic.MEDIA_PLAYBACK_PAUSE;
                            }
                        } else {
                            debug("playlist restarted from track %d", index);
                            if (step > 0) {
                                music.play_next(step);
                            } else if (step < 0) {
                                music.play_prev(-step);
                            }
                            music.paused = false;
                        }

                        return;
                    });
                
                playlist.changed.connect((file_path_list) => {
                        List<string> list = file_path_list.copy_deep((src) => {
                                return src.dup();
                            });
                        if (list.length() > 0) {
                            finder_add_button.sensitive = true;
                        }
                        if (music.playing) {
                            music.set_file_list(ref list);
                        } else {
                            music.start(ref list, options.ao_type);
                            ((Gtk.Image)play_pause_button.icon_widget).icon_name = IconName.Symbolic.MEDIA_PLAYBACK_PAUSE;
                            (header_switch_button.image as Image).icon_name = IconName.Symbolic.VIEW_GRID;
                            header_switch_button.sensitive = true;
                            stack.show_playlist();
                        }
                        next_track_button.sensitive = true;
                    });
            }
            playlist_view_container.add(playlist);
        }

        if (!options.use_csd) {
            playlist_vbox.pack_start(playlist_toolbar, false, false);
        }
        playlist_vbox.pack_start(playlist_view_container, true, true);
    }
    
    //----------------------------------------------------------------------------------
    // Creating artwork view (overlay)
    //----------------------------------------------------------------------------------
    music_view_overlay = new Overlay();
    {
        music_view_close_button = new Button.from_icon_name(IconName.Symbolic.WINDOW_CLOSE, IconSize.BUTTON);
        {
            music_view_close_button.halign = Align.END;
            music_view_close_button.valign = Align.START;
            music_view_close_button.margin = 10;
            music_view_close_button.clicked.connect(() => {
                    artwork_button.visible = true;
                    music_view_overlay.visible = false;
                    header_switch_button.sensitive = true;
                    finder_add_button.sensitive = true;
                });
        }

        music_view_container = new ScrolledWindow(null, null);
        {
            music_view_container.get_style_context().add_class(StyleClass.ARTWORK_BACKGROUND);
        }

        music_view_artwork = new Image();
        {
            music_view_artwork.margin = 0;
            music_view_container.add(music_view_artwork);
        }

        music_view_overlay.add(music_view_container);
        music_view_overlay.add_overlay(music_view_close_button);
        music_view_overlay.set_overlay_pass_through(music_view_close_button, true);
    }

    //----------------------------------------------------------------------------------
    // Creating music player manager (control for MPlayer)
    //----------------------------------------------------------------------------------
    music = new Music();
    {
        music.on_quit.connect((pid, status) => {
                time_bar.set_value(0.0);
                time_label_set(0);

                ((Gtk.Image)play_pause_button.icon_widget).icon_name = IconName.Symbolic.MEDIA_PLAYBACK_START;
            });
    
        music.on_start.connect((track_number, file_path) => {
                debug("on start func start");

                DFileInfo file_info = playlist.nth_track_data(track_number);

                music_title.label = (file_info.title != null) ? file_info.title : file_info.name;
                if (options.use_csd) {
                    win_header.set_title(music_title.label);
                } else {
                    main_win.title = music_title.label;
                }
                music_total_time = file_info.time_length;
                music_total_time_seconds = MyUtils.TimeUtils.minutes_to_seconds(music_total_time);
                music_time_position = 0.0;
                if (music_total_time.length > 5) {
                    time_label_set = (current_time) => {
                        double current_hours = Math.floor(current_time / 360);
                        double current_minutes = Math.floor(current_time / 60);
                        double current_seconds = Math.floor(current_time % 60);
                        double current_milliseconds = Math.floor(current_time * 10 % 10);
                        time_label_current.label = "%02.0f:%02.0f:%02.0f.%01.0f".printf(current_hours,
                                                                                        current_minutes,
                                                                                        current_seconds,
                                                                                        current_milliseconds);
                        double rest_time_total = music_total_time_seconds - current_time;
                        double rest_hours = Math.floor(rest_time_total / 360);
                        double rest_minutes = Math.floor(rest_time_total / 60);
                        double rest_seconds = Math.floor(rest_time_total % 60);
                        time_label_rest.label = "%02.0f:%02.0f:%02.0f".printf(rest_hours,
                                                                              rest_minutes,
                                                                              rest_seconds);
                    };
                } else {
                    time_label_set = (current_time) => {
                        double current_minutes = Math.floor(current_time / 60);
                        double current_seconds = Math.floor(current_time % 60);
                        double current_milliseconds = Math.floor(current_time * 10 % 10);
                        time_label_current.label = "%02.0f:%02.0f.%01.0f".printf(current_minutes,
                                                                                 current_seconds,
                                                                                 current_milliseconds);
                        double rest_time_total = music_total_time_seconds - current_time;
                        double rest_minutes = Math.floor(rest_time_total / 60);
                        double rest_seconds = Math.floor(rest_time_total % 60);
                        time_label_rest.label = "%02.0f:%02.0f".printf(rest_minutes,
                                                                          rest_seconds);
                    };
                }
                time_label_rest.label = music_total_time;
                time_label_set(0);
                time_bar.set_value(0.0);
                Timeout.add(100, () => {
                        if (track_number != music.get_current_track_number() || !music.playing) {
                            return Source.REMOVE;
                        }

                        if (!music.paused) {
                            music_time_position += 0.1;
                            time_label_set(music_time_position);
                            time_bar.set_value(music_time_position / music_total_time_seconds);
                        }
                        return Source.CONTINUE;
                    }, Priority.DEFAULT);

                ((Gtk.Image)play_pause_button.icon_widget).icon_name = IconName.Symbolic.MEDIA_PLAYBACK_PAUSE;

                play_pause_button.sensitive = true;
                next_track_button.sensitive = !playlist.track_is_last();
                prev_track_button.sensitive = true;

                playlist.set_track(track_number);
                
                debug("artwork_max_size: " + artwork_max_size.to_string());
                current_playing_artwork = file_info.artwork;
                if (current_playing_artwork != null) {
                    artwork.set_from_pixbuf(MyUtils.PixbufUtils.scale(current_playing_artwork,
                                                                              options.thumbnail_size));
                    if (!music_view_artwork.visible) {
                        artwork_button.visible = true;
                        debug("make artwork button visible");
                    }
                    Idle.add(() => {
                            debug("enter timeout artwork size");
                            int size = int.min(music_view_container.get_allocated_width(),
                                               music_view_container.get_allocated_height());
                            music_view_artwork.pixbuf = MyUtils.PixbufUtils.scale(current_playing_artwork,
                                                                                  size);
                            debug("music view artwork size: " + size.to_string());
                            return Source.REMOVE;
                        });
                } else {
                    artwork_button.visible = false;
                    music_view_artwork.set_from_icon_name(IconName.AUDIO_FILE, IconSize.LARGE_TOOLBAR);
                }

            });

        music.on_end.connect((track_number, track_name) => {
                // ???
                //playlist.set_track(-1);
            });
    }
    
    //----------------------------------------------------------------------------------
    // Creating the main window
    //----------------------------------------------------------------------------------
    main_win = new Window();
    {
        var top_box = new Box(Orientation.VERTICAL, 0);
        {
            var main_overlay = new Overlay();
            {
                stack = new MpdStack(//finder_hbox,
                    finder_paned,
                    playlist_vbox,
                    options.use_csd);
                {
                    stack.finder_is_selected.connect(() => {
                            header_add_button.visible = false;
                            header_switch_button.tooltip_text = Text.TOOLTIP_SHOW_PLAYLIST;
                        });
                    stack.playlist_is_selected.connect(() => {
                            header_add_button.visible = true;
                            header_switch_button.tooltip_text = Text.TOOLTIP_SHOW_FINDER;
                        });
                }
                
                main_overlay.add(stack);
                main_overlay.add_overlay(music_view_overlay);
            }
            
            top_box.pack_start(main_overlay, true, true);
            top_box.pack_start(controller, false, false);
        }

        main_win.add(top_box);
        if (options.use_csd) {
            main_win.set_titlebar(win_header);
        } else {
            main_win.title = "dplayer : directory player";
        }
        main_win.border_width = 0;
        main_win.window_position = WindowPosition.CENTER;
        main_win.resizable = true;
        main_win.has_resize_grip = true;
        main_win.set_default_size(window_default_width, window_default_height);

        main_win.destroy.connect(application_quit);
        main_win.configure_event.connect((cr) => {
                if (music_view_overlay.visible && current_playing_artwork != null) {
                    int size = int.min(music_view_container.get_allocated_width(),
                                       music_view_container.get_allocated_height());
                    music_view_artwork.pixbuf = MyUtils.PixbufUtils.scale(current_playing_artwork, size);
                }
                bookmark_title_col.max_width = main_win.get_allocated_width() / 4;
                return false;
            });

        main_win.show_all();
    }

    //----------------------------------------------------------------------------------
    // Reading a style sheet
    //----------------------------------------------------------------------------------
    if (FileUtils.test(css_path, FileTest.EXISTS)) {
        Gdk.Screen win_screen = main_win.get_screen();
        CssProvider css_provider = new CssProvider();
        try {
            css_provider.load_from_path(css_path);
        } catch (Error e) {
            debug("ERROR: css_path: %s", css_path);
            stderr.printf(Text.ERROR_CREATE_WINDOW);
            return 1;
        }
        Gtk.StyleContext.add_provider_for_screen(win_screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
    }
    
    //----------------------------------------------------------------------------------
    // Starting this program
    //----------------------------------------------------------------------------------
    artwork_button.visible = false;
    music_view_overlay.visible = false;
    music_view_artwork.visible = false;
    finder.hide_while_label();
    (header_switch_button.image as Image).icon_name = IconName.Symbolic.VIEW_LIST;
    header_switch_button.sensitive = false;
    finder_add_button.sensitive = false;
    finder_zoomout_button.sensitive = true;
    finder_zoomin_button.sensitive = true;
    stack.show_finder();
    finder.change_dir(current_dir);
    if (options.last_playlist_name != "") {
        load_playlist_from_file(options.last_playlist_name,
                                get_playlist_path_from_name(options.last_playlist_name));
    }

    Gtk.main();

    //----------------------------------------------------------------------------------
    // Finishing this program
    //----------------------------------------------------------------------------------
    config_file_contents = "";

    config_file_contents =
        "ao_type=%s\n"+
        "thumbnail_size=%d\n"+
        "use_csd=%s\n"+
        "cwd=%s\n"+
        "playlist_image_size=%d\n"+
        "icon_size=%d\n"+
        "playlist_name=%s\n";
    config_file_contents = config_file_contents.printf(
            options.ao_type,
            options.thumbnail_size,
            (options.use_csd ? "true" : "false"),
            current_dir,
            options.playlist_image_size,
            options.icon_size,
            (options.last_playlist_name != null ? options.last_playlist_name : "")
            );
    foreach (string dir in dirs) {
        config_file_contents += "dir=" + dir + "\n";
    }


    try {
        FileUtils.set_contents(config_file_path, config_file_contents);
    } catch (Error e) {
        stderr.printf(Text.ERROR_WRITE_CONFIG);
        Process.exit(1);
    }

    return 0;
}
