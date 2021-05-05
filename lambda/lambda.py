import image_checker
import image_scraper

def base_image_checker_handler(event, context):
  current_sha = image_checker.get_digest()
  image_checker.create_or_update_stored_sha(current_sha)

def image_scraper_handler(event, context):
  MAJOR_VERSIONS = [
      "2.3",
      "2.4",
      "2.5",
      "2.6",
      "2.7",
      "3.0"
   ]

  for major_version in MAJOR_VERSIONS:
    all_versions = image_scraper.fetch_minor_versions(major_version)
    for minor_version in all_versions:
      image_scraper.add_build_to_queue(major_version, minor_version)
