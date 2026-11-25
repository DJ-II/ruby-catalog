module InventoryCommentsHelper
  def inventory_comment_markdown(content)
    renderer = Redcarpet::Render::HTML.new(escape_html: true, safe_links_only: true, no_images: true)
    markdown = Redcarpet::Markdown.new(renderer, autolink: true, fenced_code_blocks: true, tables: true)
    sanitize(markdown.render(content.to_s),
             tags: %w[p br strong em del code pre blockquote ul ol li a h1 h2 h3 h4 hr table thead tbody tr th td],
             attributes: %w[href title])
  end
end
