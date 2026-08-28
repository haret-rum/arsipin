class ArchivePage < Jekyll::PageWithoutAFile
  def initialize(site, dir, data)
    super(site, site.source, dir, "index.html")
    data.each { |key, value| self.data[key] = value }
  end
end

class ArchivePagesGenerator < Jekyll::Generator
  safe true
  priority :low

  def generate(site)
    per_page = site.config.fetch("paginate", 7).to_i
    per_page = 1 if per_page < 1

    category_archive_type = site.config.dig("category_archive", "type")
    unless category_archive_type == "jekyll-archives"
      generate_taxonomy_pages(site, "categories", site.categories, per_page)
    end

    tag_archive_type = site.config.dig("tag_archive", "type")
    unless tag_archive_type == "jekyll-archives"
      generate_taxonomy_pages(site, "tags", site.tags, per_page)
      generate_all_tags_page(site, per_page)
    end

    generate_archive_pagination_pages(site, "tags", site.tags, per_page) if tag_archive_type == "jekyll-archives"
    generate_archive_pagination_pages(site, "categories", site.categories, per_page) if category_archive_type == "jekyll-archives"

    generate_author_pages(site, per_page)
  end

  private

  def generate_taxonomy_pages(site, type, taxonomies, per_page)
    return unless taxonomies.is_a?(Hash)

    taxonomies.each do |name, documents|
      next if name.nil? || name.to_s.strip.empty?

      posts = visible_posts(Array(documents))
      archive_data = {
        "layout" => "archive-taxonomy",
        "title" => name.to_s,
        "taxonomy" => name.to_s,
        "taxonomy_type" => type
      }
      generate_paginated_pages(site, "/#{type}/#{slug(name)}", posts, per_page, archive_data)
    end
  end

  def generate_all_tags_page(site, per_page)
    posts = visible_posts(site.posts.docs)
    tag_names = site.tags.to_h.keys.map { |name| name.to_s.strip }.reject(&:empty?)

    generate_paginated_pages(site, "/tags", posts, per_page, {
      "layout" => "archive-taxonomy",
      "title" => "Tags",
      "taxonomy" => "tags",
      "taxonomy_type" => "tags",
      "tag_names" => tag_names
    })
  end

  def generate_author_pages(site, per_page)
    authors = site.data.fetch("authors", {})
    authors.each_key do |name|
      author_posts = site.posts.docs.select do |post|
        author_key(post.data["author"]) == author_key(name)
      end
      posts = visible_posts(author_posts)
      generate_paginated_pages(site, "/authors/#{slug(name)}", posts, per_page, {
        "layout" => "author",
        "title" => name.to_s,
        "author" => name.to_s,
        "author_name" => name.to_s
      })
    end
  end

  def generate_archive_pagination_pages(site, type, taxonomies, per_page)
    return unless taxonomies.is_a?(Hash)

    taxonomies.each do |name, documents|
      posts = visible_posts(Array(documents))
      total_pages = [(posts.length.to_f / per_page).ceil, 1].max
      next if total_pages <= 1

      (2..total_pages).each do |page_number|
        page_posts = posts[((page_number - 1) * per_page), per_page] || []
        base_path = "/#{type}/#{slug(name)}"
        page_data = {
          "layout" => "archive-taxonomy",
          "title" => name.to_s,
          "taxonomy" => name.to_s,
          "taxonomy_type" => type,
          "posts" => page_posts,
          "archive_page" => page_number,
          "archive_per_page" => per_page,
          "archive_total_posts" => posts.length,
          "archive_total_pages" => total_pages,
          "archive_previous" => pagination_path(base_path, page_number - 1),
          "archive_next" => page_number < total_pages ? pagination_path(base_path, page_number + 1) : nil
        }
        page = ArchivePage.new(site, "#{base_path}/page/#{page_number}".sub(%r{^/}, ""), page_data)
        page.content = ""
        site.pages << page
      end
    end
  end

  def generate_paginated_pages(site, base_path, posts, per_page, data)
    posts = Array(posts).compact
    total_pages = [(posts.length.to_f / per_page).ceil, 1].max

    (1..total_pages).each do |page_number|
      page_posts = posts[((page_number - 1) * per_page), per_page] || []
      page_path = page_number == 1 ? base_path : "#{base_path}/page/#{page_number}"
      page_data = data.merge(
        "archive_posts" => page_posts,
        "pagination" => {
          "page" => page_number,
          "per_page" => per_page,
          "posts" => page_posts,
          "total_posts" => posts.length,
          "total_pages" => total_pages,
          "previous_page_path" => page_number > 1 ? pagination_path(base_path, page_number - 1) : nil,
          "next_page_path" => page_number < total_pages ? pagination_path(base_path, page_number + 1) : nil
        }
      )
      page = ArchivePage.new(site, page_path.sub(%r{^/}, ""), page_data)
      page.content = ""
      site.pages << page
    end
  end

  def pagination_path(base_path, page_number)
    page_number == 1 ? "#{base_path}/" : "#{base_path}/page/#{page_number}/"
  end

  def visible_posts(posts)
    posts.select { |post| post.data["hidden"] != true }.sort_by(&:date).reverse
  end

  def slug(value)
    Jekyll::Utils.slugify(value.to_s)
  end

  def author_key(value)
    value.to_s.downcase.gsub(/[.]/, "").gsub(/\s+/, " ").strip
  end
end
