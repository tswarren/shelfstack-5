# frozen_string_literal: true

# Barby 0.7.0 builds SVG path/rect markup with `path_data = ''` / `rects = ''` then `<<`.
# Ruby 3.4 warns that those literals will be frozen in a future release. Use mutable strings.
require "barby/outputter/svg_outputter"

module BarbySvgMutableStrings
  def bars_to_rects(opts = {})
    rects = String.new
    with_options opts do
      x, y = lmargin, tmargin

      if barcode.two_dimensional?
        boolean_groups.each do |line|
          line.each do |bar, amount|
            bar_width = xdim * amount
            if bar
              rects << %Q(<rect x="#{x}" y="#{y}" width="#{bar_width}px" height="#{ydim}px" />\n)
            end
            x += bar_width
          end
          y += ydim
          x = lmargin
        end
      else
        boolean_groups.each do |bar, amount|
          bar_width = xdim * amount
          if bar
            rects << %Q(<rect x="#{x}" y="#{y}" width="#{bar_width}px" height="#{height}px" />\n)
          end
          x += bar_width
        end
      end
    end

    rects
  end

  def bars_to_path_data(opts = {})
    path_data = String.new
    with_options opts do
      x, y = lmargin + (xdim / 2), tmargin

      if barcode.two_dimensional?
        booleans.each do |line|
          line.each do |bar|
            path_data << "M#{x} #{y}V #{y + ydim}" if bar
            x += xdim
          end
          y += ydim
          x = lmargin + (xdim / 2)
        end
      else
        booleans.each do |bar|
          path_data << "M#{x} #{y}V#{y + height}" if bar
          x += xdim
        end
      end
    end

    path_data
  end
end

Barby::SvgOutputter.prepend(BarbySvgMutableStrings)
