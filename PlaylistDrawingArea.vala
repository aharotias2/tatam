using Gdk;
using Gtk;
using Cairo;
using MyUtils;

namespace DPlayer {
    public enum PlaylistItemStatus {
            NORMAL, PLAYING, PAUSED, HIDDEN,
        }
    
    public class PlaylistDrawingArea : Bin {
        private DrawingArea area;
        public PlaylistItemStatus status { get; set; }
        public int size { get; set; }
        public RGBA circle_line_color { get; set; }
        public RGBA circle_fill_color { get; set; }
        public RGBA foreground_color { get; set; }
        public uint index { get; set; }
        public bool does_draw_outline { get; set; }
        public double circle_size_percentage { get; set; }
        public double font_size_percentage { get; set; }
        public double pause_height_percentage { get; set; }
        
        public PlaylistDrawingArea() {
            status = PlaylistItemStatus.NORMAL;
            size = 64;
            index = 1;
            does_draw_outline = false;
            circle_size_percentage = 0.6;
            font_size_percentage = 0.27;
            pause_height_percentage = 0.27;
            circle_line_color = RGBAUtils.new_rgba_from_string("FFFFFF", 0.7);
            circle_fill_color = RGBAUtils.new_rgba_from_string("FFFFFF", 0.5);
            foreground_color = RGBAUtils.new_rgba_from_string("000000", 0.7);
            area = new DrawingArea();
            {
                area.set_size_request(size, size);
                area.draw.connect(on_draw);
            }
            add(area);
        }

        public void set_area_size(int new_size) {
            size = new_size;
            set_size_request(size, size);
        }
        
        protected bool on_draw(Widget da, Context ctx) {
            draw_circle(da, ctx);
            switch (status) {
            case PlaylistItemStatus.NORMAL:
                draw_number(da, ctx);
                break;
            case PlaylistItemStatus.PLAYING:
                draw_pause_icon(da, ctx);
                break;
            case PlaylistItemStatus.PAUSED:
                draw_playback_icon(da, ctx);
                break;
            case PlaylistItemStatus.HIDDEN:
            default:
                break;
            }
            return true;
        }

        protected void draw_circle(Widget da, Context ctx) {
            double red = circle_line_color.red;
            double green = circle_line_color.green;
            double blue = circle_line_color.blue;
            double alpha = circle_line_color.alpha;
            int half_size = size / 2;
            ctx.arc(half_size, half_size, half_size * circle_size_percentage, 0.0, 360.0 * (Math.PI / 180.0));
            if (does_draw_outline) {
                ctx.set_source_rgba(red, green, blue, alpha);
                ctx.set_line_width(1.0);
                ctx.stroke_preserve();
            }
            red = circle_fill_color.red;
            green = circle_fill_color.green;
            blue = circle_fill_color.blue;
            alpha = circle_fill_color.alpha;
            ctx.set_source_rgba(red, green, blue, alpha);
            ctx.fill();
        }

        protected void draw_number(Widget da, Context ctx) {
            double red = foreground_color.red;
            double green = foreground_color.green;
            double blue = foreground_color.blue;
            double alpha = foreground_color.alpha;
            TextExtents extents;
            string text = index.to_string();
            ctx.set_font_size(size * font_size_percentage);
            ctx.set_source_rgba(red, green, blue, alpha);
            ctx.text_extents(text, out extents);
            ctx.move_to(size / 2 - extents.width / 2, size / 2 + extents.height / 2);
            ctx.show_text(text);
        }

        protected void draw_playback_icon(Widget da, Context ctx) {
            double red = foreground_color.red;
            double green = foreground_color.green;
            double blue = foreground_color.blue;
            double alpha = foreground_color.alpha;
            int width = (int) (size * 0.3);
            int half_width = width / 2;
            int height = (int) Math.sqrt(width * width - half_width * half_width);
            int x1 = size / 2 - height / 3;
            int y1 = size / 2 - half_width;
            int x2 = size / 2 - height / 3;
            int y2 = size / 2 + half_width;
            int x3 = size / 2 + height / 3 * 2;
            int y3 = size / 2;
            ctx.set_source_rgba(red, green, blue, alpha);
            ctx.move_to(x1, y1);
            ctx.line_to(x2, y2);
            ctx.line_to(x3, y3);
            ctx.close_path();
            ctx.fill();
        }

        protected void draw_pause_icon(Widget da, Context ctx) {
            double red = foreground_color.red;
            double green = foreground_color.green;
            double blue = foreground_color.blue;
            double alpha = foreground_color.alpha;
            int width = (int) (size * 0.1);
            int height = (int) (size * pause_height_percentage);
            int space = (int) (size * 0.05);
            int half_size = size / 2;
            int half_height = height / 2;
            int half_space = (int) (space / 2.0);
            int x1 = half_size - half_space - width;
            int y1 = half_size - half_height;
            int x3 = half_size + half_space;
            int y3 = y1;
            ctx.set_line_width(0);
            ctx.set_source_rgba(red, green, blue, alpha);
            ctx.rectangle(x1, y1, width, height);
            ctx.fill();
            ctx.rectangle(x3, y3, width, height);
            ctx.fill();
        }
    }
}
