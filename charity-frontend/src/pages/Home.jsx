import React from 'react';
import { Link } from 'react-router-dom';

const Home = () => {
  const quotes = [
    {
      text: 'We make a living by what we get, but we make a life by what we give.',
      author: 'Winston Churchill',
    },
    {
      text: "Giving is not just about making a donation, it's about making a difference.",
      author: 'Kathy Calvin',
    },
    {
      text: "Happiness doesn't result from what we get, but from what we give.",
      author: 'Ben Carson',
    },
    {
      text: 'The meaning of life is to find your gift. The purpose of life is to give it away.',
      author: 'Pablo Picasso',
    },
    { text: 'Giving opens the way for receiving.', author: 'Florence Scovel Shinn' },
    {
      text: 'You have not lived today until you have done something for someone who can never repay you.',
      author: 'John Bunyan',
    },
    {
      text: 'It is every man’s obligation to put back into the world at least the equivalent of what he takes out of it.',
      author: 'Albert Einstein',
    },
    { text: 'No one has ever become poor by giving.', author: 'Anne Frank' },
    {
      text: 'Only by giving are you able to receive more than you already have.',
      author: 'Jim Rohn',
    },
    {
      text: 'The best way to find yourself is to lose yourself in the service of others.',
      author: 'Mahatma Gandhi',
    },
  ];

  return (
    <div className="home">
      {/* Navbar */}
      <nav className="bg-orange-500 text-white py-4 px-8 flex justify-between items-center">
        <div className="text-2xl font-bold">CharityHub</div>
        <ul className="flex gap-4">
          <li>
            <Link
              to="/about"
              className="hover:underline"
            >
              About Us
            </Link>
          </li>
          <li>
            <Link
              to="/donate"
              className="hover:underline"
            >
              Donate
            </Link>
          </li>
          <li>
            <Link
              to="/leaderboard"
              className="hover:underline"
            >
              Leaderboard
            </Link>
          </li>
          <li>
            <Link
              to="/contact"
              className="hover:underline"
            >
              Contact
            </Link>
          </li>
        </ul>
      </nav>

      {/* Hero Section */}
      <header className="relative bg-gradient-to-r from-orange-500 to-orange-400 text-white h-[80vh] flex flex-col justify-center items-center text-center">
        <h1 className="text-4xl md:text-6xl font-bold mb-4 animate-fade-in-up">
          Make a Difference Today
        </h1>
        <p className="text-lg md:text-2xl mb-6 animate-fade-in-up delay-100">
          "No one has ever become poor by giving." - Anne Frank
        </p>
        <Link
          to="/donate"
          className="bg-white text-orange-500 px-6 py-3 rounded-full font-bold text-lg shadow-md hover:bg-gray-100 transition"
        >
          Donate Now
        </Link>
        <div className="absolute bottom-4 text-xl animate-bounce">Scroll ⬇️ down</div>
      </header>

      {/* Quotes Section */}
      <section className="bg-gray-100 py-16">
        <h2 className="text-center text-3xl font-bold text-orange-500 mb-8">Why Give?</h2>
        <div className="overflow-hidden relative max-w-5xl mx-auto">
          <div className="flex gap-8 animate-slide-in">
            {quotes.map((quote, index) => (
              <div
                key={index}
                className="min-w-[300px] bg-white shadow-lg rounded-lg p-6 text-center transform transition hover:scale-105"
              >
                <blockquote className="italic text-lg mb-4">{`"${quote.text}"`}</blockquote>
                <p className="font-bold text-orange-500">{`- ${quote.author}`}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
};

export default Home;
