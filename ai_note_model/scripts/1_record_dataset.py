#!/usr/bin/env python3
"""
STEP 1 — Record Your Own Voice Dataset
=======================================
Record voice samples for training WITH full playback support.

After every recording you can:
  p  — PLAY back and listen to what you just recorded
  k  — KEEP it and move to the next sentence
  r  — RE-RECORD if it didn't sound right
  s  — SKIP this sentence
  q  — QUIT and save progress

Usage:
    py -3.11 scripts/1_record_dataset.py

Install (if needed):
    py -3.11 -m pip install sounddevice soundfile scipy numpy
"""

import os
import csv
import wave
import time
import threading
import numpy as np

# ── Try importing audio libraries ─────────────────────────────────
try:
    import sounddevice as sd
    import soundfile as sf
    HAS_AUDIO = True
except ImportError:
    HAS_AUDIO = False
    print("⚠️  sounddevice / soundfile not installed.")
    print("   py -3.11 -m pip install sounddevice soundfile scipy")
    print("   Falling back to MANUAL mode\n")

# ── Paste your SENTENCES list here ────────────────────────────────
# (copy from training_sentences.py for full 500 sentences)
SENTENCES = [
 
    # ── UNIVERSITY LECTURES — Computer Science & AI (1–60) ──────
    "The lecture today covers the fundamentals of machine learning",
    "Neural networks are computational models inspired by the human brain",
    "Deep learning uses multiple stacked layers to learn data representations",
    "The training loss decreased significantly after ten epochs of training",
    "Gradient descent is an optimization algorithm used to minimize the loss function",
    "Overfitting occurs when a model memorizes the training data instead of generalizing",
    "We use dropout regularization to prevent overfitting in deep neural networks",
    "The validation accuracy reached eighty five percent after fine tuning",
    "Convolutional neural networks are primarily used for image classification tasks",
    "Recurrent neural networks are designed to handle sequential and time series data",
    "The transformer architecture uses self attention mechanisms for natural language processing",
    "Backpropagation is the algorithm used to compute gradients in neural networks",
    "The softmax function converts raw logits into probability distributions",
    "Batch normalization helps stabilize and accelerate the training process",
    "Transfer learning allows us to reuse a pretrained model for a new task",
    "The BERT model was pretrained on a large corpus using masked language modeling",
    "Support vector machines find the optimal hyperplane to separate classes",
    "Decision trees recursively split data based on feature values",
    "Random forests combine multiple decision trees to improve prediction accuracy",
    "K-means clustering groups data points into k distinct clusters",
    "Principal component analysis reduces the dimensionality of high dimensional data",
    "The confusion matrix shows the performance of a classification model",
    "Precision measures the proportion of true positives among predicted positives",
    "Recall measures the proportion of true positives among actual positives",
    "The F1 score is the harmonic mean of precision and recall",
    "Cross validation helps evaluate model performance on unseen data",
    "Hyperparameter tuning improves model performance through systematic search",
    "The learning rate controls how much the model weights are updated each step",
    "Momentum helps the optimizer escape local minima during training",
    "The Adam optimizer combines momentum and adaptive learning rates",
    "Data augmentation artificially increases the size of the training dataset",
    "Object detection models identify and locate objects within images",
    "Semantic segmentation assigns a class label to every pixel in an image",
    "Natural language processing deals with the interaction between computers and human language",
    "Tokenization splits text into individual words or subword units",
    "Word embeddings represent words as dense numerical vectors in a high dimensional space",
    "The attention mechanism allows models to focus on relevant parts of the input",
    "Generative adversarial networks consist of a generator and a discriminator",
    "Reinforcement learning trains agents to take actions in an environment to maximize reward",
    "The Q-learning algorithm learns the value of actions in each state",
    "Speech recognition converts spoken audio into written text",
    "The Wav2Vec2 model uses self supervised learning for speech representation",
    "Connectionist temporal classification is used for sequence labeling tasks",
    "The word error rate measures the accuracy of a speech recognition system",
    "Audio preprocessing involves resampling converting to mono and normalizing amplitude",
    "The fast Fourier transform converts a time domain signal into the frequency domain",
    "Mel frequency cepstral coefficients are widely used features for audio analysis",
    "Convolutional neural networks can also be applied to audio spectrograms",
    "The encoder decoder architecture is commonly used in sequence to sequence models",
    "Beam search is a decoding strategy that explores multiple candidate sequences",
    "The BLEU score evaluates the quality of machine translated text",
    "Named entity recognition identifies and classifies named entities in text",
    "Part of speech tagging assigns grammatical labels to each word in a sentence",
    "Dependency parsing analyzes the grammatical structure of a sentence",
    "Sentiment analysis determines whether text expresses positive negative or neutral opinion",
    "Text summarization condenses a long document into a shorter version",
    "Question answering systems retrieve or generate answers from a given context",
    "Knowledge graphs represent entities and relationships in a structured format",
    "Federated learning trains models across decentralized devices without sharing raw data",
    "Edge computing brings computation and data storage closer to the source of data",
 
    # ── UNIVERSITY LECTURES — Mathematics & Statistics (61–110) ─
    "Calculus is the mathematical study of continuous change",
    "The derivative measures the rate of change of a function",
    "The integral computes the area under a curve between two points",
    "Linear algebra deals with vectors matrices and linear transformations",
    "Matrix multiplication is a fundamental operation in machine learning",
    "The determinant of a matrix indicates whether the matrix is invertible",
    "Eigenvalues and eigenvectors describe the scaling effect of a linear transformation",
    "Probability theory provides the mathematical foundation for statistics",
    "The normal distribution is a symmetric bell shaped probability distribution",
    "The central limit theorem states that the sum of random variables tends toward a normal distribution",
    "Bayes theorem relates conditional probabilities using prior and posterior distributions",
    "Statistical hypothesis testing evaluates whether observed data supports a claim",
    "The p value measures the probability of observing results as extreme as the data",
    "Regression analysis models the relationship between variables",
    "Logistic regression is used for binary classification problems",
    "The coefficient of determination measures how well a model fits the data",
    "Variance measures the spread of data points around the mean",
    "Standard deviation is the square root of the variance",
    "The correlation coefficient measures the strength and direction of a linear relationship",
    "Time series analysis studies data points collected at successive time intervals",
    "Fourier analysis decomposes a signal into its constituent frequencies",
    "Graph theory studies the properties of graphs consisting of nodes and edges",
    "A binary tree is a hierarchical data structure where each node has at most two children",
    "Dynamic programming solves complex problems by breaking them into simpler subproblems",
    "Big O notation describes the upper bound of an algorithm's time complexity",
    "Sorting algorithms arrange elements of a list in a specific order",
    "The quicksort algorithm uses a divide and conquer strategy",
    "Breadth first search explores all nodes at the current depth before moving deeper",
    "Depth first search explores as far as possible along each branch before backtracking",
    "Dijkstra's algorithm finds the shortest path between nodes in a weighted graph",
    "Hash tables provide average constant time complexity for insertion and lookup",
    "A stack follows the last in first out principle",
    "A queue follows the first in first out principle",
    "Linked lists store elements as nodes where each node points to the next",
    "Binary search efficiently finds a target value in a sorted array",
    "Recursion is a technique where a function calls itself to solve smaller subproblems",
    "Object oriented programming organizes code around objects and classes",
    "Encapsulation hides internal implementation details from external access",
    "Inheritance allows a class to inherit properties and methods from a parent class",
    "Polymorphism allows objects of different types to be treated as the same type",
    "Design patterns provide reusable solutions to common software design problems",
    "The singleton pattern ensures only one instance of a class exists",
    "The observer pattern defines a one to many dependency between objects",
    "Version control systems track changes to source code over time",
    "Continuous integration automatically builds and tests code after each commit",
    "Unit testing verifies that individual functions work correctly in isolation",
    "Integration testing checks that different components work together correctly",
    "The agile methodology uses iterative cycles called sprints",
    "Code review is the practice of examining source code by peers before merging",
    "Documentation helps future developers understand the purpose of the code",
 
    # ── UNIVERSITY LECTURES — Engineering & Sciences (111–160) ──
    "Thermodynamics studies the relationship between heat work and energy",
    "Newton's first law states that an object at rest remains at rest",
    "The speed of light in a vacuum is approximately three hundred million meters per second",
    "Quantum mechanics describes the behavior of particles at the atomic scale",
    "The periodic table organizes chemical elements by atomic number",
    "Photosynthesis is the process by which plants convert sunlight into glucose",
    "DNA carries the genetic instructions for the development of living organisms",
    "Evolution explains the diversity of life through natural selection",
    "The greenhouse effect causes the Earth's atmosphere to retain heat",
    "Electrical resistance is measured in ohms",
    "Ohm's law states that voltage equals current multiplied by resistance",
    "Semiconductors have electrical conductivity between conductors and insulators",
    "The operating system manages hardware resources and provides services to applications",
    "Memory management allocates and deallocates memory for running processes",
    "The CPU executes instructions by fetching decoding and executing them",
    "Cache memory reduces the time to access data from the main memory",
    "Parallel computing performs multiple computations simultaneously",
    "Cloud computing provides on demand access to shared computing resources",
    "Virtualization allows multiple operating systems to run on a single physical machine",
    "Containerization packages applications with their dependencies into isolated environments",
    "Network protocols define rules for communication between devices",
    "The TCP IP model is the foundational framework for internet communication",
    "Encryption protects data by transforming it into an unreadable format",
    "Public key cryptography uses a pair of keys for secure communication",
    "Firewalls monitor and filter incoming and outgoing network traffic",
    "SQL is a language used for managing relational databases",
    "NoSQL databases store data in flexible non tabular formats",
    "Indexing improves the speed of data retrieval operations in databases",
    "ACID properties ensure reliable database transactions",
    "Database normalization reduces data redundancy by organizing tables efficiently",
    "REST APIs use HTTP methods to enable communication between systems",
    "JSON is a lightweight data interchange format widely used in web development",
    "Microservices architecture breaks applications into small independent services",
    "Load balancing distributes incoming traffic across multiple servers",
    "Caching stores frequently accessed data to reduce response time",
    "Message queues enable asynchronous communication between services",
    "DevOps combines software development and operations to improve deployment speed",
    "Infrastructure as code manages and provisions computing resources through scripts",
    "Kubernetes orchestrates containerized applications across a cluster of machines",
    "The internet of things connects physical devices to the internet",
    "Blockchain is a distributed ledger that records transactions securely",
    "Augmented reality overlays digital content onto the real world",
    "Virtual reality creates an immersive simulated environment",
    "Robotics combines mechanical engineering software and electronics",
    "Computer vision enables machines to interpret and understand visual information",
    "Autonomous vehicles use sensors and AI to navigate without human input",
    "Bioinformatics applies computational methods to analyze biological data",
    "The human genome contains approximately three billion base pairs",
    "CRISPR is a gene editing technology that can modify DNA sequences",
    "Nanotechnology manipulates matter at the atomic and molecular scale",
 
    # ── MEETINGS & PROFESSIONAL (161–280) ────────────────────────
    "Let us begin today's meeting by reviewing the agenda",
    "The project deadline is set for the end of next month",
    "We need to finalize the requirements before development begins",
    "The client has requested additional features for the next sprint",
    "Let me share my screen to show the latest progress",
    "The team completed all tasks assigned in the previous sprint",
    "We identified three critical bugs that need to be fixed immediately",
    "The performance tests showed a significant improvement in response time",
    "We should schedule a follow up meeting to discuss the feedback",
    "The budget for this quarter has been approved by management",
    "The new feature will be released in the next production build",
    "Please update the project documentation before the end of the week",
    "The user interface design has been reviewed and approved by the client",
    "We are behind schedule by two days and need to catch up",
    "The database migration was completed successfully last night",
    "The API integration with the third party service is now working",
    "We need to add unit tests for the authentication module",
    "The pull request has been reviewed and is ready to merge",
    "The staging environment is set up and ready for testing",
    "We discovered a memory leak in the recording module",
    "The code review identified several areas for improvement",
    "We need to discuss the architecture before writing any more code",
    "The mobile app has been tested on both Android and iOS devices",
    "The Firebase configuration has been updated for the production environment",
    "The team will present the demo to stakeholders on Friday",
    "We need to optimize the database queries to improve performance",
    "The user acceptance testing will begin next Monday",
    "The security audit revealed two vulnerabilities that need to be patched",
    "The deployment pipeline has been set up using continuous integration",
    "The sprint retrospective will be held tomorrow afternoon",
    "I would like to raise a concern about the current timeline",
    "Can everyone confirm their availability for the next two weeks",
    "The technical specification document needs to be updated",
    "We agreed to use the agile methodology for this project",
    "The product backlog has been prioritized based on business value",
    "The QA team will begin testing the new features tomorrow",
    "We need to improve the error handling in the backend service",
    "The server costs have increased due to higher usage this month",
    "The marketing team has requested a new dashboard feature",
    "The mobile app notification system is now fully integrated",
    "The team has been divided into two groups for parallel development",
    "The release notes have been drafted and are ready for review",
    "We should add more logging to help with future debugging",
    "The customer support team reported three new issues this week",
    "The onboarding flow has been redesigned based on user feedback",
    "The analytics dashboard is showing a twenty percent increase in daily active users",
    "We need to discuss the plan for handling increased traffic during the launch",
    "The backend team will complete the API endpoints by Wednesday",
    "The design team has finalized the new color scheme and typography",
    "The project manager will send out the updated timeline by tomorrow",
    "Action items from today's meeting will be sent via email",
    "Please make sure all tasks are updated in the project management tool",
    "The next release is scheduled for the fifteenth of this month",
    "We should create a risk register to track potential project risks",
    "The team leads will present their progress updates every Monday morning",
    "The client approved the wireframes and we can proceed to development",
    "We are waiting for access credentials from the infrastructure team",
    "The support ticket has been escalated to the senior developer",
    "The integration tests are passing on all major platforms",
    "The team worked overtime to meet the critical deadline",
    "I will follow up with the vendor about the delayed delivery",
    "The project kickoff meeting is scheduled for next Tuesday at ten",
    "We need to define the acceptance criteria for each user story",
    "The sprint velocity has improved compared to the previous iteration",
    "All team members should review the updated coding standards",
    "The database schema has been updated to support the new features",
    "We will conduct a knowledge transfer session before the handover",
    "The infrastructure costs are within the allocated budget",
    "The team has successfully completed the proof of concept",
    "We need to address the technical debt accumulated over the past sprints",
    "The beta version will be released to a selected group of users",
    "The monitoring dashboard is showing all services are healthy",
    "We should document the deployment process for future reference",
    "The load testing results indicate the system can handle one thousand concurrent users",
    "The hotfix has been deployed to production and the issue is resolved",
    "The quarterly review meeting will be held on the last Friday of the month",
    "We need to align with the business team on the product roadmap",
    "The user research findings will be presented in tomorrow's meeting",
    "The API documentation has been published on the developer portal",
    "We agreed to postpone the feature to the next major release",
    "The accessibility audit showed the application meets the required standards",
    "The new team member will be onboarded starting from Monday",
    "We should improve the app store listing to increase downloads",
    "The payment integration has been tested in the sandbox environment",
    "The error rate has dropped significantly after the latest fix",
    "The team is confident we will meet the release target",
    "Please review the updated terms of service before the meeting",
    "The performance optimization reduced the app startup time by forty percent",
    "We need to plan the migration from the old system to the new platform",
    "The weekly status report will be sent to all stakeholders every Friday",
    "The feature flags allow us to roll out changes gradually",
    "The production incident has been resolved and a postmortem will be conducted",
    "The team will attend a training workshop on cloud architecture next week",
    "The vendor has confirmed delivery of the hardware by end of month",
    "All developers should review and sign the updated security policy",
    "The A/B test results show that version B has a higher conversion rate",
    "The engineering team will present the technical proposal to the board",
    "The mobile app update has been submitted to the app store for review",
    "We are implementing two factor authentication for improved security",
    "The project charter has been signed by all key stakeholders",
    "The retrospective feedback will be incorporated into the next sprint planning",
    "The cloud infrastructure has been migrated to the new region",
    "We need to improve the test coverage to at least eighty percent",
    "The UI redesign has improved the user satisfaction score significantly",
    "The contract with the new vendor has been reviewed by the legal team",
    "The capacity planning exercise suggests we need two more developers",
    "The new onboarding checklist has reduced setup time by half",
    "The team demonstrated the completed features during the sprint review",
    "The risk assessment identified three high priority items to address",
    "We will use feature branches and pull requests for all code changes",
    "The technical architecture review is scheduled for Thursday afternoon",
    "The data backup and recovery procedures have been tested and verified",
 
    # ── PERSONAL NOTES (281–380) ──────────────────────────────────
    "Today I need to buy groceries milk bread eggs and vegetables",
    "I have a dentist appointment on Thursday at two thirty",
    "I should call mom and check in on how she is doing",
    "I want to finish reading the book I started last week",
    "I need to pay the electricity bill before the due date",
    "My gym session starts at six thirty tomorrow morning",
    "I should prepare my presentation slides before Friday",
    "I need to renew my library membership this week",
    "I want to try the new restaurant that opened near the university",
    "I should back up my laptop files to the external hard drive",
    "I need to reply to the email from my professor about the assignment",
    "I want to start learning a new programming language this month",
    "I should organize my desk and clean up my workspace",
    "I need to submit my project report by midnight tonight",
    "I want to go for a walk in the park this evening",
    "I should prepare a study schedule for the upcoming exams",
    "I need to pick up the package from the post office tomorrow",
    "I want to cook a healthy meal instead of ordering takeout",
    "I should check the bus schedule for the early morning route",
    "I need to transfer money to my savings account before the weekend",
    "I want to watch the documentary I bookmarked last month",
    "I should charge my laptop and phone before going to bed",
    "I need to return the library books by Thursday",
    "I want to learn how to cook a new recipe this weekend",
    "I should review my notes from today's lecture before sleeping",
    "I need to print the assignment and submit it in class tomorrow",
    "I want to complete the online course I enrolled in last month",
    "I should set a reminder for the team meeting at nine tomorrow",
    "I need to buy a new notebook for the upcoming semester",
    "I want to catch up with my friends over the weekend",
    "I should update my resume with my latest project experience",
    "I need to register for the exam before the registration deadline",
    "I want to finish the coding exercise before the tutorial session",
    "I should drink more water throughout the day",
    "I need to fix the bug in my personal project before tomorrow",
    "I want to go to the library and study for three hours",
    "I should review the flashcards for tomorrow's quiz",
    "I need to fill up my water bottle and pack my bag for class",
    "I want to take a short nap before the evening lecture",
    "I should research internship opportunities for the summer break",
    "I need to get a haircut before the job interview next week",
    "I want to plan a trip with my friends during the semester break",
    "I should read through the project feedback from my supervisor",
    "I need to install the required software before the lab session",
    "I want to write in my journal about the progress I made today",
    "I should stretch and exercise for at least thirty minutes today",
    "I need to confirm my attendance for the workshop on Monday",
    "I want to organize my digital files into proper folders",
    "I should buy a new phone charger as mine is broken",
    "I need to upload the assignment to the online submission portal",
    "I want to check if there are any scholarships I can apply for",
    "I should prepare questions to ask during the guest lecture tomorrow",
    "I need to refill my medication prescription before it runs out",
    "I want to spend some time this weekend on a personal side project",
    "I should text my study group about the meeting time and venue",
    "I need to label and organize my study notes by subject",
    "I want to complete the tutorial on data visualization this afternoon",
    "I should check the weather forecast before planning outdoor activities",
    "I need to follow up with my internship application status",
    "I want to reduce my screen time before going to sleep",
    "I should review the grading rubric before submitting the report",
    "I need to connect my Bluetooth headphones to the new phone",
    "I want to learn more about cloud computing during the holidays",
    "I should prepare a list of topics to discuss with my academic advisor",
    "I need to attend the career fair at the university this Wednesday",
    "I want to improve my typing speed by practicing every day",
    "I should save my project files to both local and cloud storage",
    "I need to respond to the group chat about the presentation schedule",
    "I want to track my daily habits using a simple checklist",
    "I should research the best laptop for programming and development",
    "I need to submit my leave application before the end of the week",
    "I want to start waking up earlier to have more productive mornings",
    "I should read the recommended research paper before the seminar",
    "I need to bring my student ID to the examination hall",
    "I want to practice coding problems for at least one hour daily",
    "I should create a budget plan for the upcoming month",
    "I need to update my LinkedIn profile with my recent projects",
    "I want to complete all pending assignments before the weekend",
    "I should review the terms and conditions before signing the contract",
    "I need to coordinate with my teammates about the final deliverable",
    "I want to maintain a consistent sleep schedule for better focus",
    "I should prepare a short self introduction for the networking event",
    "I need to finalize my project topic and submit the proposal today",
    "I want to explore new study techniques to improve my retention",
    "I should check my email every morning and respond within the day",
    "I need to buy a new pair of earphones for online classes",
    "I want to volunteer for the university tech event next month",
    "I should make a grocery list before going to the supermarket",
    "I need to tidy up my room and do the laundry this weekend",
    "I want to finish the self assessment form for the performance review",
    "I should print and read the course outline for the new module",
    "I need to update the dependencies in my project before deployment",
    "I want to take a full day off this Sunday to rest and recharge",
    "I should test my internet connection before the online examination",
    "I need to prepare a summary of the chapter for tomorrow's discussion",
    "I want to attend the seminar on artificial intelligence next Thursday",
    "I should double check all my answers before submitting the exam",
    "I need to save the research paper links into my reference manager",
    "I want to build a small app to practice what I learned this week",
    "I should install the code linter and formatter in my development environment",
    "I need to clear the browser cache and cookies to fix the loading issue",
 
    # ── MIXED DOMAIN — Short & Clear sentences for ASR (381–500) ─
    "Please open the terminal and navigate to the project folder",
    "Run the command to install the required dependencies",
    "The build was successful with no errors or warnings",
    "I will push the changes to the main branch after review",
    "The function returns a list of strings sorted alphabetically",
    "The variable name should be descriptive and follow naming conventions",
    "Add a comment to explain the purpose of this code block",
    "The loop iterates through each element in the array",
    "The condition checks whether the input value is null or empty",
    "The async function awaits the result of the API call",
    "Handle the exception and display a meaningful error message",
    "The class inherits from the base model and overrides the build method",
    "Import the required packages at the top of the file",
    "The constructor initializes all required fields and sets default values",
    "Refactor this method to reduce its complexity and improve readability",
    "Write a test case to verify the expected output of this function",
    "The configuration file stores environment variables and API endpoints",
    "Deploy the updated version to the staging server for testing",
    "The logs show that the request failed with a five hundred error",
    "Increase the timeout duration to handle slow network connections",
    "The data is serialized to JSON before being sent over the network",
    "Parse the response and extract the relevant fields",
    "The model was trained on a dataset of ten thousand audio samples",
    "Fine tuning improves the model's performance on domain specific tasks",
    "Save the model checkpoint after every hundred training steps",
    "Load the pretrained weights and freeze the lower layers",
    "The inference time is under two seconds on a standard laptop",
    "Monitor the training loss and validation accuracy on the dashboard",
    "The dataset was split into eighty percent training and twenty percent testing",
    "Normalize the audio to have zero mean and unit variance",
    "Convert the audio file to sixteen kilohertz mono format",
    "The transcription pipeline processes audio files in batches",
    "The greedy decoder selects the most probable token at each step",
    "Evaluate the model using the word error rate metric",
    "The vocabulary was built from the training transcripts",
    "Tokenize the sentence into individual characters for CTC training",
    "The Flask server starts on port five thousand by default",
    "Send a POST request to the transcribe endpoint with the audio file",
    "The health check endpoint returns the model status and device information",
    "The server runs on your local machine and listens on all interfaces",
    "Connect to the server using the local IP address of your computer",
    "The mobile app sends the recorded audio to the Flask API",
    "The response contains the transcribed text and inference duration",
    "Firebase stores the user profile and notes in Firestore collections",
    "Authentication is handled by Firebase using email and password",
    "The notes are synced in real time across all user devices",
    "The recording is saved as an M4A file in temporary storage",
    "Export the note as a PDF and share it using the native share sheet",
    "The keyword extraction identifies the most frequent words in the transcript",
    "The summary is generated by extracting the first two sentences",
    "Good morning everyone let us get started with today's session",
    "Thank you for attending and please feel free to ask questions",
    "That concludes today's lecture and we will continue next week",
    "Does anyone have any questions before we move on",
    "Please make sure to submit the assignment before the deadline",
    "The exam will cover all topics discussed in the last four weeks",
    "Study groups are encouraged to collaborate on the practice problems",
    "Office hours are available on Tuesday and Thursday from two to four",
    "The tutorial session will be held in the computer lab on level two",
    "Please bring your student ID to every examination",
    "The attendance policy requires at least eighty percent presence",
    "Late submissions will be penalized five percent per day",
    "The project accounts for forty percent of the final grade",
    "Group presentations will be held during the last week of semester",
    "Please review the marking rubric before submitting your work",
    "Any academic misconduct will result in serious consequences",
    "The supplementary reading list is available on the course portal",
    "Guest lecturers will be invited for the advanced topics module",
    "The lab equipment must be handled with care and returned after use",
    "Please log off the computer at the end of each lab session",
    "The results of the midterm examination have been posted online",
    "Make sure your code is well commented before the demonstration",
    "The final project must include a written report and a live demo",
    "Teams of three to four students are required for the group project",
    "The project proposal must be approved before development begins",
    "The grading will be based on functionality design and documentation",
    "All references must be cited using the APA format",
    "Plagiarism detection software will be used to check all submissions",
    "The assignment requires both a written component and a practical task",
    "Please use the discussion forum for any questions about the course",
    "Updates to the timetable will be announced through the official portal",
    "The department will host a career fair for final year students",
    "Industry mentors are available to provide guidance on final year projects",
    "The scholarship application deadline is at the end of this month",
    "Students are encouraged to participate in hackathons and competitions",
    "The university provides free access to all major software development tools",
    "Research opportunities are available for high achieving students",
    "The student council is organizing a tech fest for all departments",
    "Please register your attendance using the QR code at the entrance",
    "The library has extended its opening hours during the exam period",
    "Digital copies of all textbooks are available through the library portal",
    "The computer science department welcomes all students to the new semester",
    "Remember to take regular breaks and look after your mental health",
    "Time management is one of the most important skills for university success",
    "Do not hesitate to reach out to your academic advisor if you need support",
    "Building a strong portfolio will help you stand out in the job market",
    "Networking with professionals in your field can open many career opportunities",
    "Learning to communicate clearly is as important as technical skills",
    "Always back up your work to avoid losing progress unexpectedly",
    "Version control is an essential skill for every software developer",
    "Start your assignments early to allow time for revision and improvement",
    "Reading documentation carefully can save hours of debugging time",
    "The best way to learn programming is to build real projects",
    "Consistency and practice are the keys to mastering any technical skill",
 
    # ── Extra sentences to complete 500 ─────────────────────────
    "The microphone permission must be granted before recording begins",
    "Tap the record button to start capturing your voice",
    "The audio file is saved in M4A format after recording stops",
    "The transcription result is displayed on the note detail screen",
    "You can search your notes using keywords from the transcript",
    "The note has been saved successfully to your library",
    "Swipe left on a note card to reveal the delete option",
    "Tap the star icon to mark a note as your favourite",
    "The export button allows you to share the note as a PDF",
    "The profile screen shows your total notes and recording minutes",
    "Sign out from the profile screen using the sign out button",
    "The app supports dark mode for comfortable night time use",
    "Connect to the same WiFi network as your computer to use the AI",
    "The AI server must be running before you start recording",
    "Start the Flask server by running python flask underscore api slash app dot py",
    "The server processes your audio and returns the transcription result",
    "The model was trained specifically on your own voice samples",
    "Recording more samples improves the accuracy of the transcription",
    "The language setting controls how your notes are categorized",
    "You can choose between English Sinhala and Tamil for your recordings",
    "The keyword tags help you quickly find related notes later",
    "Thank you for using Note Lingo your personal AI note assistant",
    "Your voice is the most natural way to capture ideas and information",
]

# ── Config ─────────────────────────────────────────────────────────
SAMPLE_RATE  = 16000
CHANNELS     = 1
DATASET_DIR  = "dataset"
AUDIO_DIR    = os.path.join(DATASET_DIR, "audio")
METADATA_CSV = os.path.join(DATASET_DIR, "metadata.csv")

os.makedirs(AUDIO_DIR, exist_ok=True)

# ── Terminal colours ───────────────────────────────────────────────
R   = "\033[91m"
G   = "\033[92m"
Y   = "\033[93m"
B   = "\033[94m"
C   = "\033[96m"
W   = "\033[97m"
DIM = "\033[2m"
X   = "\033[0m"
def clr(t, c): return f"{c}{t}{X}"

# ── Load existing metadata ─────────────────────────────────────────
existing = set()
if os.path.exists(METADATA_CSV):
    with open(METADATA_CSV, "r") as f:
        for row in csv.DictReader(f):
            existing.add(row["file"])

# ── Recording engine ───────────────────────────────────────────────
_recording    = False
_audio_buffer = []
_rec_thread   = None

def _record_worker():
    global _audio_buffer
    _audio_buffer = []
    with sd.InputStream(samplerate=SAMPLE_RATE, channels=CHANNELS,
                        dtype="float32") as stream:
        while _recording:
            chunk, _ = stream.read(SAMPLE_RATE // 10)
            _audio_buffer.extend(chunk[:, 0].tolist())

def start_recording():
    global _recording, _rec_thread
    _recording  = True
    _rec_thread = threading.Thread(target=_record_worker, daemon=True)
    _rec_thread.start()

def stop_recording():
    global _recording
    _recording = False
    if _rec_thread:
        _rec_thread.join(timeout=2)
    return np.array(_audio_buffer, dtype=np.float32)

def play_audio(audio):
    print(f"  {clr('▶  Playing back your recording…', C)}", flush=True)
    try:
        # Resample 16000 Hz → 44100 Hz (system output rate)
        # Playing at 16000 Hz causes silence on most systems
        OUT_RATE = 44100
        old_len   = len(audio)
        new_len   = int(old_len * OUT_RATE / SAMPLE_RATE)
        indices   = np.linspace(0, old_len - 1, new_len)
        left      = np.floor(indices).astype(int)
        right     = np.clip(left + 1, 0, old_len - 1)
        frac      = indices - left
        resampled = audio[left] * (1 - frac) + audio[right] * frac
        sd.play(resampled, samplerate=OUT_RATE)
        sd.wait()
        print(f"  {clr('⏹  Playback done.', DIM)}")
    except Exception as e:
        print(f"  {clr(f'⚠️  Playback error: {e}', Y)}")
        print(f"  {clr('Tip: check your speakers/headphones are connected.', DIM)}")

def save_wav(audio, filepath):
    audio_int16 = (audio * 32767).clip(-32768, 32767).astype(np.int16)
    with wave.open(filepath, "w") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(audio_int16.tobytes())

def fmt_dur(s):
    return f"{int(s)//60:02d}:{int(s)%60:02d}"

# ── Main loop ──────────────────────────────────────────────────────
def record_dataset():
    recorded_count = len(existing)

    print()
    print(clr("╔══════════════════════════════════════════════╗", B))
    print(clr("║   Note Lingo — Dataset Recorder  v2         ║", B))
    print(clr("╚══════════════════════════════════════════════╝", B))
    print()
    print(f"  Already recorded : {clr(str(recorded_count), G)} samples")
    print(f"  Sentences queued : {clr(str(len(SENTENCES)), W)}")
    print(f"  Target           : {clr('100+', Y)} samples recommended")
    print()
    print(clr("  Controls after recording:", W))
    print(f"    {clr('p', C)} → Play back and listen")
    print(f"    {clr('k', G)} → Keep it, save and continue")
    print(f"    {clr('r', Y)} → Re-record same sentence again")
    print(f"    {clr('s', DIM)} → Skip this sentence")
    print(f"    {clr('q', R)} → Quit and save progress")
    print()

    with open(METADATA_CSV, "a", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)
        if recorded_count == 0:
            writer.writerow(["file", "transcript", "duration"])

        sample_idx = recorded_count

        for sentence in SENTENCES:
            filename = f"sample_{sample_idx:04d}.wav"
            if filename in existing:
                continue

            filepath = os.path.join(AUDIO_DIR, filename)

            # ── Show sentence ──────────────────────────────────────
            print(f"\n  {clr('─' * 52, DIM)}")
            print(f"  {clr(f'Sample #{sample_idx + 1}', B)}  "
                  f"{clr(f'({sample_idx + 1}/{len(SENTENCES)})', DIM)}")
            print()
            print(f"  {clr('📢  Say this sentence:', W)}")
            print()
            print(f"    {clr(sentence, Y)}")
            print()

            # ── Pre-record prompt ──────────────────────────────────
            cmd = input(
                f"  Press {clr('ENTER', G)} to start recording"
                f"  |  {clr('s', DIM)}=skip"
                f"  |  {clr('q', R)}=quit : "
            ).strip().lower()

            if cmd == "q":
                print(f"\n  {clr('✅  Progress saved. Goodbye!', G)}")
                break
            if cmd == "s":
                print(f"  {clr('⏩  Skipped.', DIM)}")
                continue

            # ── Recording + playback loop ──────────────────────────
            current_audio = None

            while True:
                if not HAS_AUDIO:
                    print(f"  Manual mode: place WAV at {filepath}")
                    if os.path.exists(filepath):
                        writer.writerow([filename, sentence.lower(), "manual"])
                        csvfile.flush()
                        sample_idx += 1
                        print(f"  {clr('✅  Added.', G)}")
                    break

                # ── RECORD ────────────────────────────────────────
                print()
                print(f"  {clr('🔴  RECORDING…', R)}  "
                      f"(press {clr('ENTER', W)} to stop)")
                start_recording()
                t0 = time.time()

                input()   # ← blocks here while mic is recording

                audio    = stop_recording()
                duration = time.time() - t0

                # Too short check
                if len(audio) < SAMPLE_RATE * 0.5:
                    print(f"  {clr('⚠️  Too short! Please record at least 1 second.', Y)}")
                    print(f"  {clr('🔄  Try again…', Y)}")
                    continue

                current_audio = audio
                dur_str = fmt_dur(duration)
                print()
                print(f"  {clr('⏹  Recording stopped', W)}  "
                      f"[ {clr(dur_str, C)} | "
                      f"{clr(str(len(audio)), DIM)} samples ]")

                # ── Post-recording menu ───────────────────────────
                print()
                print(f"  {clr('What do you want to do?', W)}")
                print(f"    {clr('p', C)} — ▶  Play back and listen")
                print(f"    {clr('k', G)} — ✅  Keep and save")
                print(f"    {clr('r', Y)} — 🔄  Re-record this sentence")
                print(f"    {clr('s', DIM)} — ⏩  Skip this sentence")
                print()

                choice = input("  Your choice [p/k/r/s] : ").strip().lower()

                # ── PLAY ──────────────────────────────────────────
                if choice == "p":
                    print()
                    play_audio(current_audio)
                    print()
                    print(f"  {clr('After listening:', W)}")
                    print(f"    {clr('k', G)} — ✅  Keep it")
                    print(f"    {clr('r', Y)} — 🔄  Re-record")
                    print(f"    {clr('p', C)} — ▶  Play again")
                    print()

                    while True:
                        after = input("  Your choice [k/r/p] : ").strip().lower()
                        if after == "p":
                            print()
                            play_audio(current_audio)
                            print()
                        elif after == "r":
                            choice = "r"
                            break
                        else:
                            choice = "k"
                            break

                # ── KEEP ──────────────────────────────────────────
                if choice == "k" or choice == "":
                    save_wav(current_audio, filepath)
                    writer.writerow([filename, sentence.lower(),
                                     f"{duration:.2f}"])
                    csvfile.flush()
                    sample_idx += 1
                    print()
                    print(f"  {clr(f'✅  Saved!  →  {filename}', G)}  "
                          f"{clr(f'({dur_str})', DIM)}")
                    break

                # ── RE-RECORD ─────────────────────────────────────
                elif choice == "r":
                    print()
                    print(f"  {clr('🔄  Re-recording same sentence…', Y)}")
                    print()
                    print(f"    {clr(sentence, Y)}")
                    continue

                # ── SKIP ──────────────────────────────────────────
                elif choice == "s":
                    print(f"  {clr('⏩  Skipped.', DIM)}")
                    break

                else:
                    # Unknown input → default keep
                    save_wav(current_audio, filepath)
                    writer.writerow([filename, sentence.lower(),
                                     f"{duration:.2f}"])
                    csvfile.flush()
                    sample_idx += 1
                    print(f"  {clr(f'✅  Saved → {filename}', G)}")
                    break

    # ── Summary ───────────────────────────────────────────────────
    total = sample_idx
    print()
    print(clr("  ╔══════════════════════════════════════╗", G))
    print(clr("  ║   Session complete!                  ║", G))
    print(clr("  ╚══════════════════════════════════════╝", G))
    print()
    print(f"  Total samples saved : {clr(str(total), G)}")
    print(f"  CSV file            : {clr(METADATA_CSV, W)}")
    print(f"  Audio folder        : {clr(AUDIO_DIR, W)}")
    print()
    if total < 50:
        print(clr("  ⚠️  Tip: Record at least 50–100 samples for decent accuracy.", Y))
        print(clr("          The more you record, the better your model.", Y))
    else:
        print(clr(f"  ✅  Great! {total} samples ready.", G))
    print()
    print(f"  {clr('Next step:', W)}  "
          f"{clr('py -3.11 scripts/2_prepare_dataset.py', C)}")
    print()


if __name__ == "__main__":
    record_dataset()