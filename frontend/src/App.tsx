import React, { useState } from 'react';
import { PackageSearch } from 'lucide-react';
import { KinesisClient, PutRecordCommand } from '@aws-sdk/client-kinesis';

interface ProductFormData {
  name: string;
  description: string;
  price: string;
  category: string;
  sku: string;
  stockQuantity: string;
  imageUrl: string;
}

const initialFormData: ProductFormData = {
  name: '',
  description: '',
  price: '',
  category: '',
  sku: '',
  stockQuantity: '',
  imageUrl: ''
};

function App() {
  const [formData, setFormData] = useState<ProductFormData>(initialFormData);
  const [products, setProducts] = useState<ProductFormData[]>([]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };
  const sendToKinesis = async (payload:ProductFormData) => {
    try {
      const params = {
        StreamName: 'view-analytics-stream',
        Data: new TextEncoder().encode(JSON.stringify({
          payload,
          timestamp: new Date().toISOString()
        })),
        PartitionKey: 'partition-' + Date.now()
      };

      const command = new PutRecordCommand(params);
      const response = await client.send(command);
      console.log(response);
    } catch (error) {
      console.error('Error sending to Kinesis:', error);
    }
  };
  const client = new KinesisClient({
    region: 'us-east-1'
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setProducts(prev => [...prev, formData]);
    sendToKinesis(formData);
    setFormData(initialFormData);
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-50 to-gray-100 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto">
        <div className="text-center mb-8">
          <div className="bg-white p-3 rounded-full inline-block shadow-md">
            <PackageSearch className="h-12 w-12 text-indigo-600" />
          </div>
          <h2 className="mt-4 text-3xl font-extrabold text-gray-900">Product Information</h2>
          <p className="mt-2 text-sm text-gray-600">Enter the details for your new product</p>
        </div>

        <div className="bg-white shadow-lg rounded-xl p-8">
          <form className="space-y-6">
            <div>
              <label htmlFor="name" className="block text-sm font-semibold text-gray-700 mb-1">Product Name</label>
              <input
                type="text"
                name="name"
                id="name"
                required
                value={formData.name}
                onChange={handleChange}
                className="form-input block w-full rounded-lg border-gray-200 bg-gray-50 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-200 transition duration-150 ease-in-out"
                placeholder="Enter product name"
              />
            </div>

            <div>
              <label htmlFor="description" className="block text-sm font-semibold text-gray-700 mb-1">Description</label>
              <textarea
                name="description"
                id="description"
                required
                value={formData.description}
                onChange={handleChange}
                rows={3}
                className="form-textarea block w-full rounded-lg border-gray-200 bg-gray-50 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-200 transition duration-150 ease-in-out"
                placeholder="Enter product description"
              />
            </div>

            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div>
                <label htmlFor="price" className="block text-sm font-semibold text-gray-700 mb-1">Price ($)</label>
                <div className="relative">
                  <span className="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-500">$</span>
                  <input
                    type="number"
                    name="price"
                    id="price"
                    required
                    min="0"
                    step="0.01"
                    value={formData.price}
                    onChange={handleChange}
                    className="form-input block w-full pl-8 rounded-lg border-gray-200 bg-gray-50 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-200 transition duration-150 ease-in-out"
                    placeholder="0.00"
                  />
                </div>
              </div>

              <div>
                <label htmlFor="category" className="block text-sm font-semibold text-gray-700 mb-1">Category</label>
                <select
                  name="category"
                  id="category"
                  required
                  value={formData.category}
                  onChange={handleChange}
                  className="form-select block w-full rounded-lg border-gray-200 bg-gray-50 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-200 transition duration-150 ease-in-out"
                >
                  <option value="">Select a category</option>
                  <option value="electronics">Electronics</option>
                  <option value="clothing">Clothing</option>
                  <option value="books">Books</option>
                  <option value="home">Home & Garden</option>
                  <option value="toys">Toys</option>
                </select>
              </div>

              <div>
                <label htmlFor="sku" className="block text-sm font-semibold text-gray-700 mb-1">SKU</label>
                <input
                  type="text"
                  name="sku"
                  id="sku"
                  required
                  value={formData.sku}
                  onChange={handleChange}
                  className="form-input block w-full rounded-lg border-gray-200 bg-gray-50 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-200 transition duration-150 ease-in-out"
                  placeholder="Enter SKU"
                />
              </div>

              <div>
                <label htmlFor="stockQuantity" className="block text-sm font-semibold text-gray-700 mb-1">Stock Quantity</label>
                <input
                  type="number"
                  name="stockQuantity"
                  id="stockQuantity"
                  required
                  min="0"
                  value={formData.stockQuantity}
                  onChange={handleChange}
                  className="form-input block w-full rounded-lg border-gray-200 bg-gray-50 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-200 transition duration-150 ease-in-out"
                  placeholder="Enter quantity"
                />
              </div>
            </div>

            <div>
              <label htmlFor="imageUrl" className="block text-sm font-semibold text-gray-700 mb-1">Image URL</label>
              <input
                type="url"
                name="imageUrl"
                id="imageUrl"
                required
                value={formData.imageUrl}
                onChange={handleChange}
                className="form-input block w-full rounded-lg border-gray-200 bg-gray-50 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-200 transition duration-150 ease-in-out"
                placeholder="Enter image URL"
              />
            </div>

            <div className="flex justify-end">
              <button
                type="button"
                onClick={handleSubmit}
                className="inline-flex justify-center py-2.5 px-6 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition duration-150 ease-in-out transform hover:scale-105"
              >
                Add Product
              </button>
            </div>
          </form>
        </div>

        {products.length > 0 && (
          <div className="mt-8">
            <h3 className="text-lg font-medium text-gray-900 mb-4">Added Products</h3>
            <div className="bg-white shadow-lg rounded-xl overflow-hidden">
              <ul className="divide-y divide-gray-200">
                {products.map((product, index) => (
                  <li key={index} className="px-6 py-5 hover:bg-gray-50 transition duration-150 ease-in-out">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center">
                        <div className="flex-shrink-0 h-14 w-14">
                          <img
                            className="h-14 w-14 rounded-lg object-cover shadow-sm"
                            src={product.imageUrl}
                            alt={product.name}
                          />
                        </div>
                        <div className="ml-4">
                          <h4 className="text-lg font-medium text-gray-900">{product.name}</h4>
                          <p className="text-sm text-gray-500 mt-1">SKU: {product.sku}</p>
                          <p className="text-sm text-indigo-600 mt-1">{product.category}</p>
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="text-lg font-semibold text-gray-900">${product.price}</div>
                        <p className="text-sm text-gray-500 mt-1">Stock: {product.stockQuantity}</p>
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default App;