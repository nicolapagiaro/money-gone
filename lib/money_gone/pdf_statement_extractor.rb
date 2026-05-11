# frozen_string_literal: true

require "open3"
require "tmpdir"

require "pdf/reader"
require "rtesseract"

module MoneyGone
  # Estrae testo da estratti PDF: prima livello testo del PDF, poi OCR (Tesseract) se il testo è insufficiente.
  class PdfStatementExtractor
    class Error < StandardError; end
    class OcrUnavailableError < Error; end

    MIN_TOTAL_CHARS = 80
    MIN_AVG_CHARS_PER_PAGE = 12

    def extract(path)
      path = File.expand_path(path)
      raise Error, "PDF non trovato: #{path}" unless File.file?(path)

      reader = PDF::Reader.new(path)
      combined = reader.pages.each_with_index.map do |page, i|
        "--- Pagina #{i + 1} ---\n#{page.text}"
      end.join("\n\n")

      return combined if meaningful_text?(combined, page_count: reader.page_count)

      ocr_text_from_pdf(path)
    end

    private

    def meaningful_text?(combined, page_count:)
      collapsed = combined.gsub(/\s+/, " ").strip
      return false if collapsed.length < MIN_TOTAL_CHARS

      pages = [page_count.to_i, 1].max
      (collapsed.length.to_f / pages) >= MIN_AVG_CHARS_PER_PAGE
    end

    def ocr_text_from_pdf(path)
      Dir.mktmpdir("money-gone-pdf") do |dir|
        images = rasterize_pdf(path, dir)
        raise OcrUnavailableError, rasterize_hint(path) if images.empty?

        lang = ENV.fetch("MONEY_GONE_OCR_LANG", "ita+eng")
        texts = images.each_with_index.map do |img, i|
          body = RTesseract.new(img, lang: lang).to_s.strip
          "--- Pagina #{i + 1} ---\n#{body}"
        end
        texts.join("\n\n")
      end
    end

    def rasterize_pdf(path, dir)
      prefix = File.join(dir, "ppm")
      _stdout, _stderr, status = Open3.capture3("pdftoppm", "-png", "-r", "300", path, prefix)
      imgs = Dir.glob("#{prefix}-*.png")
      return sort_page_paths(imgs) if status.success? && imgs.any?

      pattern = File.join(dir, "mk-%03d.png")
      _stdout, _stderr, st2 = Open3.capture3("magick", "-density", "300", path, pattern)
      imgs = Dir.glob(File.join(dir, "mk-*.png"))
      return sort_page_paths(imgs) if st2.success? && imgs.any?

      pattern_c = File.join(dir, "cv-%03d.png")
      _stdout, _stderr, st3 = Open3.capture3("convert", "-density", "300", path, pattern_c)
      imgs = Dir.glob(File.join(dir, "cv-*.png"))
      return sort_page_paths(imgs) if st3.success? && imgs.any?

      []
    end

    def sort_page_paths(paths)
      paths.sort_by { |p| File.basename(p)[/(\d+)\.png\z/, 1].to_i }
    end

    def rasterize_hint(path)
      <<~MSG.strip
        Impossibile convertire le pagine di #{path} in immagini per l'OCR.
        Installa Poppler (pdftoppm), oppure ImageMagick + Ghostscript (comandi magick o convert).
        Serve anche Tesseract con i pacchetti lingua usati in MONEY_GONE_OCR_LANG (default ita+eng).
      MSG
    end
  end
end
