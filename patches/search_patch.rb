# frozen_string_literal: true

# Redmine plugin for Document Management System "Features"
#
# Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module RedmineDmsf
  module Patches
    # Search patch
    module SearchPatch
      ##################################################################################################################
      # Overridden methods
      def self.prepended(base)
        base.singleton_class.prepend(ClassMethods)
      end

      # Class methods
      module ClassMethods
        def available_search_types
          # Removes the original Documents from searching (replaced with DMSF)
          if RedmineDmsf.remove_original_documents_module?
            super.reject { |t| t == 'documents' }
          else
            super
          end
        end
      end
    end
  end
end

# Apply the patch
if defined?(EasyPatchManager)
  EasyPatchManager.register_patch_to_be_first 'Redmine::Acts::Attachable::InstanceMethods',
                                              'RedmineDmsf::Patches::SearchPatch', prepend: true, first: true
else
  Redmine::Search.prepend RedmineDmsf::Patches::SearchPatch
end
