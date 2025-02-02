
import UIKit

protocol CollectionViewTableViewCellDelegate: AnyObject  {
    func CollectionViewTableViewCellDidTapCell(_ cell: CollectionViewTableViewCell,
                                               viewModel: TitlePreviewViewModel)
}

class CollectionViewTableViewCell: UITableViewCell {
    static let identifier = "CollectionViewTableViewCell"
    
    weak var delegate: CollectionViewTableViewCellDelegate?
    
    private var titles: [Title] = [Title]()
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 140, height: 200)
        layout.scrollDirection = .horizontal
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(TitleCollectionViewCell.self,
                                forCellWithReuseIdentifier: TitleCollectionViewCell.identifier)
        return collectionView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = .systemPink
        contentView.addSubview(collectionView)
        
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = contentView.bounds
    }
    
    public func configure(with titles: [Title]) {
        self.titles = titles
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    }
    
    private func downloadTitleAt(indexPath: IndexPath) {
        DataPersistenceManager.shared.downloadTitleWith(model: titles[indexPath.row]) { result in
            switch result {
            case .success():
                // reload downloads screen data
                NotificationCenter.default.post(name: NSNotification.Name("downloaded"), object: nil)
                // cell deki icon da burada güncellenebilir
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    private func removeTitleAt(indexPath: IndexPath) {
        DataPersistenceManager.shared.deleteTitleBy(id: titles[indexPath.row].id) { result in
            switch result {
            case .success():
                // reload downloads screen data
                NotificationCenter.default.post(name: NSNotification.Name("downloaded"), object: nil)
                // cell deki icon da burada güncellenebilir
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
}

extension CollectionViewTableViewCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        print("runned")
        let model = titles[indexPath.row]
        guard let titleName = model.original_title ?? model.original_name else {
            return
        }
        
        APICaller.shared.getMovie(with: titleName + " trailer") { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let videoElement):
                let model = self?.titles[indexPath.row]
                let viewModel = TitlePreviewViewModel(title: titleName,
                                                      titleOverview: model?.overview ?? "No content!",
                                                      youtubeVideo: videoElement,
                                                      titleModel: model!)
                self?.delegate?.CollectionViewTableViewCellDidTapCell(strongSelf, viewModel: viewModel)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
}

extension CollectionViewTableViewCell: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        print(indexPath.row)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return titles.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleCollectionViewCell.identifier, for: indexPath) as? TitleCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        if let model = titles[indexPath.row].poster_path {
            cell.configure(with: model)
        }
        
        return cell
    }
    
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let config = UIContextMenuConfiguration(identifier: nil,
                                                previewProvider: nil) { [weak self] _ in
            
            var action: UIAction?
            
            DataPersistenceManager.shared.isDownloaded(self?.titles[indexPath.row].id ?? 0) { result in
                switch result {
                case .success(let isDownloaded):
                    if isDownloaded {
                        action = UIAction(title: "Delete",
                                                      subtitle: nil,
                                                      image: nil,
                                                      identifier: nil,
                                                      discoverabilityTitle: nil,
                                                      state: .off) { _ in
                            self?.removeTitleAt(indexPath: indexPath)
                        }
                    } else {
                            action = UIAction(title: "Download",
                                                          subtitle: nil,
                                                          image: nil,
                                                          identifier: nil,
                                                          discoverabilityTitle: nil,
                                                          state: .off) { _ in
                                self?.downloadTitleAt(indexPath: indexPath)
                        }
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                    action = UIAction(title: "Download",
                                                  subtitle: nil,
                                                  image: nil,
                                                  identifier: nil,
                                                  discoverabilityTitle: nil,
                                                  state: .off) { _ in
                        self?.downloadTitleAt(indexPath: indexPath)
                    }
                }
            }
            return UIMenu(title: "",
                          image: nil,
                          identifier: nil,
                          options: .displayInline,
                          children: [action!])
        }
        return config
    }
}
