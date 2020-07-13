class RMT::CLI::ReposCustom < RMT::CLI::Base

  desc 'add URL NAME', _('Creates a custom repository.')
  def add(url, name)
    url += '/' unless url.end_with?('/')

    previous_repository = Repository.find_by(external_url: url)

    if previous_repository
      raise RMT::CLI::Error.new(_('A repository by the URL %{url} already exists.') % { url: url })
    end

    repository_service.create_repository!(nil, url, {
      name: name,
      mirroring_enabled: true,
      autorefresh: true,
      enabled: 0
    }, custom: true)

    puts _('Successfully added custom repository.')
  end

  desc 'list', _('List all custom repositories')
  option :csv, type: :boolean, desc: _('Output data in CSV format')

  def list
    repositories = Repository.only_custom.order(:name)
    decorator = ::RMT::CLI::Decorators::CustomRepositoryDecorator.new(repositories)

    raise RMT::CLI::Error.new(_('No custom repositories found.')) if repositories.empty?

    if options.csv
      puts decorator.to_csv
    else
      puts decorator.to_table
    end
  end
  map 'ls' => :list

  desc 'enable ID', _('Enable mirroring of custom repository by ID')
  def enable(id)
    change_mirroring(id, true)
  end

  desc 'disable ID', _('Disable mirroring of custom repository by ID')
  def disable(id)
    change_mirroring(id, false)
  end

  desc 'remove ID', _('Remove a custom repository')
  def remove(id)
    repository = find_repository!(id)
    repository.destroy!

    puts _('Removed custom repository by ID %{id}.') % { id: id }
  end
  map 'rm' => :remove

  desc 'products ID', _('Shows products attached to a custom repository')
  option :csv, type: :boolean, desc: _('Output data in CSV format')

  def products(id)
    repository = find_repository!(id)
    products = repository.products
    decorator = ::RMT::CLI::Decorators::CustomRepositoryProductsDecorator.new(products)

    raise RMT::CLI::Error.new(_('No products attached to repository.')) if products.empty?
    if options.csv
      puts decorator.to_csv
    else
      puts decorator.to_table
    end
  end

  desc 'attach ID PRODUCT_ID', _('Attach an existing custom repository to a product')
  def attach(id, product_id)
    repository = find_repository!(id)
    product = find_product!(product_id)
    repository_service.attach_product!(product, repository)

    puts _("Attached repository to product '%{product_name}'.") % { product_name: product.name }
  end

  desc 'detach ID PRODUCT_ID', _('Detach an existing custom repository from a product')
  def detach(id, product_id)
    repository = find_repository!(id)
    product = find_product!(product_id)
    repository_service.detach_product!(product, repository)

    puts _("Detached repository from product '%{product_name}'.") % { product_name: product.name }
  end

  private

  def change_mirroring(id, set_enabled)
    repository = find_repository!(id)
    repository.change_mirroring!(set_enabled)

    puts set_enabled ? _('Repository successfully enabled.') : _('Repository successfully disabled.')
  end

  def find_repository!(id)
    repository = Repository.find_by!(id: id)
    raise StandardError unless repository.custom?
    repository
  rescue
    raise RMT::CLI::Error.new(_('Cannot find custom repository by ID %{id}.') % { id: id })
  end

  def find_product!(id)
    Product.find_by!(id: id)
  rescue ActiveRecord::RecordNotFound
    raise RMT::CLI::Error.new(_('Cannot find product by ID %{id}.') % { id: id })
  end

  def repository_service
    @repository_service ||= RepositoryService.new
  end

end
