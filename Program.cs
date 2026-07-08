using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Xml;
using System.Xml.Serialization;

namespace PlatformTest
{
    internal class Program
    {
        static async Task Main(string[] args)
        {
            var password = "password";
            var iv = GenerateIV(password.Length);
            EncryptLanguagePrices(password, iv);
            Console.WriteLine("Welcome to the Book Reading Service.  This service allows you to search for a title and author");
            Console.WriteLine("in order to determine the cost for reading a specific book.  Each language has its");
            Console.WriteLine("own difficulty and will cost a different amount based on the number of pages the book contains.");
            Console.WriteLine();
            Console.WriteLine("Enter the title:");
            string title = Console.ReadLine();
            Console.WriteLine("Enter the Author's name:");
            string author = Console.ReadLine();

            var titleResponse = await searchByTitleAndAuthor(title, author);

            for (int i = 0; i < titleResponse.Docs.Count; i++)
            {
                var book = titleResponse.Docs[i];
                Console.WriteLine();
                Console.WriteLine($"{i+1}: {book.Title} (ISBN:{book.Key}) | {book.EditionCount} Editions");
                foreach (var edition in titleResponse.Docs[0].EditionKeys)
                {
                    var editionResponse = await GetEdition(edition);
                    if(editionResponse.NumberOfPages == 0)
                    {
                        Console.WriteLine($"NumberOfPages is 0 for {edition}.");
                        continue;
                    }
                    string editionKey = editionResponse.Key;
                    string editionLanguage = editionResponse.Languages?.FirstOrDefault()?.Key;
                    // Prohibit DTD processing to prevent XXE (external entity injection).
                    var readerSettings = new XmlReaderSettings()
                    {
                        DtdProcessing = DtdProcessing.Prohibit,
                        XmlResolver = null,
                    };
                    var encryptedLanguagePrices = File.ReadAllBytes("LanguagePrices_Encrypted");
                    var unencryptedLanguagePrices = Decrypt(encryptedLanguagePrices, password, iv);
                    var textReader = new StringReader(unencryptedLanguagePrices);
                    var reader = XmlReader.Create(textReader, readerSettings);
                    XmlSerializer serializer = new XmlSerializer(typeof(BookLanguages));
                    var languages = (BookLanguages)serializer.Deserialize(reader);

                    var language = languages.LanguageList.FirstOrDefault(x => x.Code == editionLanguage);
                    if(language == null)
                    {
                        // default if not found
                        language = languages.LanguageList.First(x => x.Code == "/languages/eng");
                    }
                    var cost = editionResponse.NumberOfPages * language.Price;
                    Console.WriteLine($"Cost to read edition edition in {language.Name}: {cost.ToString("C")}");
                }
            }
            Console.WriteLine("Done.  Hit any key to exit.");
            Console.ReadLine();
        }

        private static void EncryptLanguagePrices(string password, byte[] iv)
        {
            string unencryptedContents = File.ReadAllText("LanguagePrices_Unencrypted.xml");
            var encryptedContents = Encrypt(unencryptedContents, password, iv);
            File.WriteAllBytes("LanguagePrices_Encrypted", encryptedContents);
        }

        private static byte[] Encrypt(string plainText, string password, byte[] iv)
        {
            using (var desAlg = DES.Create())
            {
                desAlg.Key = Encoding.UTF8.GetBytes(password);
                desAlg.IV = iv;
                var encryptor = desAlg.CreateEncryptor(desAlg.Key, desAlg.IV);
                using (var msEncrypt = new MemoryStream())
                {
                    using (var csEncrypt = new CryptoStream(msEncrypt, encryptor, CryptoStreamMode.Write))
                    {
                        using (var swEncrypt = new StreamWriter(csEncrypt))
                        {
                            swEncrypt.Write(plainText);
                        }
                    }
                    var encrypted = msEncrypt.ToArray();
                    return encrypted;
                }
            }
        }

        private static string Decrypt(byte[] cipherText, string password, byte[] iv)
        {
            using (var desAlg = DES.Create())
            {
                desAlg.Key = Encoding.UTF8.GetBytes(password);
                desAlg.IV = iv;
                var decryptor = desAlg.CreateDecryptor(desAlg.Key, desAlg.IV);
                using (var msDecrypt = new MemoryStream(cipherText))
                using (var csDecrypt = new CryptoStream(msDecrypt, decryptor, CryptoStreamMode.Read))
                using (var srDecrypt = new StreamReader(csDecrypt))
                {
                    var plaintext = srDecrypt.ReadToEnd();
                    return plaintext;
                }
            }
        }

        private static byte[] GenerateIV(int length)
        {
            using (var rnd = RandomNumberGenerator.Create())
            {
                var iv = new byte[length];
                rnd.GetBytes(iv);
                return iv;
            }
        }

        private static async Task<OpenLibraryEditionsResponse> GetEdition(string editionKey)
        {
            string requestUri = $"https://openlibrary.org/works/{editionKey}.json";
            var httpClient = new HttpClient();
            HttpResponseMessage response = await httpClient.GetAsync(requestUri);
            string responseBody = await response.Content.ReadAsStringAsync();
            return JsonConvert.DeserializeObject<OpenLibraryEditionsResponse>(responseBody);

        }

        private static async Task<OpenLibraryEditionsResponse> GetBookDetailsByISBNAsync(string isbn)
        {
            string requestUri = $"https://openlibrary.org/isbn/{isbn}.json";
            var httpClient = new HttpClient();
            HttpResponseMessage response = await httpClient.GetAsync(requestUri);
            string responseBody = await response.Content.ReadAsStringAsync();
            return JsonConvert.DeserializeObject<OpenLibraryEditionsResponse>(responseBody);

        }

        private static async Task<OpenLibrarySearchResponse> searchByTitleAndAuthor(string title, string author)
        {
            string query = $"title={Uri.EscapeDataString(title)}&author={Uri.EscapeDataString(author)}";
            string requestUri = $"https://openlibrary.org/search.json?{query}";
            var httpClient = new HttpClient();
            HttpResponseMessage response = await httpClient.GetAsync(requestUri);
            string responseBody = await response.Content.ReadAsStringAsync();
            return JsonConvert.DeserializeObject<OpenLibrarySearchResponse>(responseBody);
        }

        private static async Task<OpenLibrarySearchResponse> Searchbyauthor(string author)
        {
            string query = $"author:{author}";
            string requestUri = $"https://openlibrary.org/search.json?q={Uri.EscapeDataString(query)}";
            var httpClient = new HttpClient();
            HttpResponseMessage response = await httpClient.GetAsync(requestUri);
            string responseBody = await response.Content.ReadAsStringAsync();
            return JsonConvert.DeserializeObject<OpenLibrarySearchResponse>(responseBody);
        }

        private static async Task<OpenLibrarySearchResponse> Search(string isbn)
        {
            string query = $"isbn:{isbn}";
            string requestUri = $"https://openlibrary.org/search.json?q={Uri.EscapeDataString(query)}";
            var httpClient = new HttpClient();
            HttpResponseMessage response = await httpClient.GetAsync(requestUri);
            string responseBody = await response.Content.ReadAsStringAsync();
            return JsonConvert.DeserializeObject<OpenLibrarySearchResponse>(responseBody);
        }
    }

    internal class Encryption
    {
        public const int IVLength = 16;
        private static RNGCryptoServiceProvider rnd => new RNGCryptoServiceProvider();

        public byte[] Encrypt(string plainText)
        {
            if ((plainText?.Length ?? 0) == 0)
                throw new ArgumentNullException(nameof(plainText));
            using (var msEncrypt = new MemoryStream())
            {
                using (var swEncrypt = new StreamWriter(msEncrypt))
                {
                    swEncrypt.Write(plainText);
                }
                var encrypted = msEncrypt.ToArray();
                return encrypted;
            }
        }

        public string Decrypt(byte[] cipherText)
        {
            if ((cipherText?.Length ?? 0) == 0)
                throw new ArgumentNullException(nameof(cipherText));
            using (var msDecrypt = new MemoryStream(cipherText))
            using (var srDecrypt = new StreamReader(msDecrypt))
            {
                var plaintext = srDecrypt.ReadToEnd();
                return plaintext;
            }
        }
    }

    [XmlRoot(ElementName = "Languages")]
    public class BookLanguages
    {
        [XmlElement(ElementName = "Language")]
        public List<BookLanguage> LanguageList { get; set; }
    }

    public class BookLanguage
    {
        [XmlElement(ElementName = "Code")]
        public string Code { get; set; }

        [XmlElement(ElementName = "Name")]
        public string Name { get; set; }

        [XmlElement(ElementName = "Price")]
        public decimal Price { get; set; }
    }

    public class OpenLibrarySearchResponse
    {
        [JsonProperty("numFound")]
        public int NumFound { get; set; }

        [JsonProperty("start")]
        public int Start { get; set; }

        [JsonProperty("docs")]
        public List<BookDocument> Docs { get; set; }
    }

    public class BookDocument
    {
        [JsonProperty("key")]
        public string Key { get; set; }

        [JsonProperty("title")]
        public string Title { get; set; }

        [JsonProperty("author_name")]
        public List<string> AuthorName { get; set; }

        [JsonProperty("isbn")]
        public List<string> Isbn { get; set; }

        [JsonProperty("publish_date")]
        public List<string> PublishDate { get; set; }

        [JsonProperty("edition_key")]
        public List<string> EditionKeys { get; set; }

        [JsonProperty("edition_count")]
        public int EditionCount { get; set; }
    }

    public class OpenLibraryEditionsResponse
    {
        [JsonProperty("title")]
        public string Title { get; set; }

        [JsonProperty("subtitle")]
        public string Subtitle { get; set; }

        [JsonProperty("authors")]
        public List<Author> Authors { get; set; }

        [JsonProperty("publishers")]
        public List<string> Publishers { get; set; }

        [JsonProperty("publish_date")]
        public string PublishDate { get; set; }

        [JsonProperty("isbn_10")]
        public List<string> Isbn10 { get; set; }

        [JsonProperty("isbn_13")]
        public List<string> Isbn13 { get; set; }

        [JsonProperty("number_of_pages")]
        public int NumberOfPages { get; set; }

        [JsonProperty("cover")]
        public Cover Cover { get; set; }

        [JsonProperty("languages")]
        public List<Language> Languages { get; set; }

        [JsonProperty("subjects")]
        public List<string> Subjects { get; set; }

        [JsonProperty("physical_format")]
        public string PhysicalFormat { get; set; }

        [JsonProperty("key")]
        public string Key { get; set; }

    }

    public class Author
    {
        [JsonProperty("name")]
        public string Name { get; set; }

        [JsonProperty("key")]
        public string Key { get; set; }
    }

    public class Publisher
    {
        [JsonProperty("name")]
        public string Name { get; set; }
    }

    public class Cover
    {
        [JsonProperty("small")]
        public string Small { get; set; }

        [JsonProperty("medium")]
        public string Medium { get; set; }

        [JsonProperty("large")]
        public string Large { get; set; }
    }

    public class Language
    {
        [JsonProperty("key")]
        public string Key { get; set; }
    }
}

