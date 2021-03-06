/*-
 * Copyright (c) 2015-2016 Adam Bieńkowski
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

namespace IDE {
    public class CMakeProject : Project {
        private CMakeParser parser;

        public new static async Project? load (File file) {
            string root_source = Path.build_filename (file.get_path (), Constants.CMAKE_TARGET);
            if (!FileUtils.test (root_source, FileTest.EXISTS)) {
                return null;
            }

            var parser = new CMakeParser (root_source);
            var project = new CMakeProject (parser);
            return project;
        }

        public CMakeProject (CMakeParser parser) {
            this.root_path = Path.get_dirname (parser.root_source);
            this.parser = parser;

            update ();
        }

        public override void update () {
            parser.parse ();

            string? project_name = null;
            foreach (var command in parser.get_commands ()) {
                switch (command.name) {
                    case Constants.PROJECT_CMD:
                        var arguments = command.get_arguments ();
                        if (arguments.length == 1) {
                            project_name = arguments[0];
                        }

                        break;
                    case Constants.PKG_CHECK_MODULES_CMD:
                        var arguments = command.get_arguments ();
                        if (arguments.length > 2) {
                            for (int i = 3; i < arguments.length; i++) {
                                check_dependencies.add (arguments[i]);
                            }
                        }

                        break;
                    case Constants.VALA_PRECOMPILE_CMD:
                        string current_header = Constants.VALA_PRECOMPILE_HEADERS[0];

                        var arguments = command.get_arguments ();
                        if (arguments.length > 2) {
                            for (int i = 1; i < arguments.length; i++) {
                                string argument = arguments[i];
                                if (argument in Constants.VALA_PRECOMPILE_HEADERS) {
                                    current_header = argument;
                                    continue;
                                }   

                                if (current_header == Constants.VALA_PRECOMPILE_HEADERS[0]) {
                                    sources.add (Path.build_filename (Path.get_dirname (command.filename), argument));
                                } else if (current_header == Constants.VALA_PRECOMPILE_HEADERS[1]) {
                                    packages.add (argument);
                                } else if (current_header == Constants.VALA_PRECOMPILE_HEADERS[2]) {
                                    options.add (argument);
                                }
                            }
                        }

                        break;
                    default:
                        break;
                }
            }

            string basename = Path.get_basename (root_path);
            if (project_name != null && project_name != basename) {
                name = "%s (%s)".printf (project_name, basename);
            } else {
                name = basename;
            }

            var version_var = parser.find_variable_by_name ("VERSION");
            if (version_var != null) {
                version = version_var.get_first_value ();
            }

            var exec_name_var = parser.find_variable_by_name ("EXEC_NAME");
            if (exec_name_var != null) {
                exec_name = exec_name_var.get_first_value ();
            }

            var release_name_var = parser.find_variable_by_name ("RELEASE_NAME");
            if (release_name_var != null) {
                release_name = release_name_var.get_first_value ();
            }

            var library_command = parser.find_command_by_name (Constants.ADD_LIBRARY_CMD);
            if (library_command != null) {
                project_type |= ProjectType.VALA_LIBRARY;
            }

            var executable_command = parser.find_command_by_name (Constants.ADD_EXECUTABLE_CMD);
            if (executable_command != null) {
                project_type |= ProjectType.VALA_APPLICATION;
            }
        }
    }
}