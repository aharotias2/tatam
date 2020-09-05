/*
 * This file is part of tatam.
 * 
 *     tatam is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 * 
 *     tatam is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 * 
 *     You should have received a copy of the GNU General Public License
 *     along with tatam.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright 2018 Takayuki Tanaka
 */

namespace Tatam {
    public class FileInfo : Object {
        public string dir { get; set; }
        public string name { get; set; }
        public string path { get; set; }
        public string album { get; set; }
        public string artist { get; set; }
        public string comment { get; set; }
        public string genre { get; set; }
        public string title { get; set; }
        public string track { get; set; }
        public string disc { get; set; }
        public string date { get; set; }
        public uint time_length { get; set; }
        public Tatam.FileType file_type { get; set; }
        public Gdk.Pixbuf artwork { get; set; }
    }

    public FileInfo copy() {
        Tatam.FileInfo cp = new Tatam.FileInfo();
        cp.dir = this.dir;
        cp.name = this.name;
        cp.path = this.path;
        cp.album = this.album;
        cp.artist = this.artist;
        cp.comment = this.comment;
        cp.genre = this.genre;
        cp.title = this.title;
        cp.track = this.track;
        cp.disc = this.disc;
        cp.date = this.date;
        cp.time_length = this.time_length;
        cp.artwork = this.artwork;
        return b;
    }
}