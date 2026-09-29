const express = require('express');
const app = express();
const PORT = 3000;

// Middleware to parse incoming JSON request bodies
app.use(express.json());

// Dummy in-memory database
let items = [
  { id: 1, name: 'Item One', status: 'active' },
  { id: 2, name: 'Item Two', status: 'pending' }
];

// 1. GET - Fetch all items
app.get('/api/items', (req, res) => {
  res.status(200).json({ success: true, count: items.length, data: items });
});

// 2. GET - Fetch a single item by ID
app.get('/api/items/:id', (req, res) => {
  const item = items.find((i) => i.id === parseInt(req.params.id));
  if (!item) {
    return res.status(404).json({ success: false, message: 'Item not found' });
  }
  res.status(200).json({ success: true, data: item });
});

// 3. POST - Create a new item
// app.post('/api/items', (req, res) => {
//   const { name, status } = req.body;

//   if (!name) {
//     return res.status(400).json({ success: false, message: 'Name is required' });
//   }

//   const newItem = {
//     id: items.length ? items[items.length - 1].id + 1 : 1,
//     name,
//     status: status || 'pending'
//   };

//   items.push(newItem);
//   res.status(201).json({ success: true, data: newItem });
// });

// 4. PUT - Update an existing item
// app.put('/api/items/:id', (req, res) => {
//   const item = items.find((i) => i.id === parseInt(req.params.id));
//   if (!item) {
//     return res.status(404).json({ success: false, message: 'Item not found' });
//   }

//   const { name, status } = req.body;
//   if (name) item.name = name;
//   if (status) item.status = status;

//   res.status(200).json({ success: true, data: item });
// });

// // 5. DELETE - Remove an item
// app.delete('/api/items/:id', (req, res) => {
//   const itemIndex = items.findIndex((i) => i.id === parseInt(req.params.id));
//   if (itemIndex === -1) {
//     return res.status(404).json({ success: false, message: 'Item not found' });
//   }

//   items.splice(itemIndex, 1);
//   res.status(200).json({ success: true, message: 'Item deleted' });
// });
app.get('/', (req, res) => {
  res.send('<h1>Welcome to my MAC 1! </h1><p>The backend is running smoothly.</p>');
});
// Start the server
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
